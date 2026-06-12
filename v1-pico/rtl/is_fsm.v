/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * is_fsm.v -- Impedance Spectroscopy measurement orchestrator
 *
 * Drives one full IS sweep over the three fixed bio-band frequencies
 * (per SPEC §3.1 REQ-IS-001: 10 / 30 / 100 kHz) on receipt of a
 * single-cycle is_sweep_start pulse from scheduler.v. For each
 * frequency:
 *
 *   1. assert dds_enable + freq_sel so DDS+DAC drive ELEC_A
 *   2. wait the analog settling time per SPEC §7.3
 *        100 kHz: 10 µs · 30 kHz: 33 µs · 10 kHz: 100 µs
 *   3. SAMPLES_PER_FREQ pairs of (I, Q) ADC samples — the analog
 *      mixer has already demodulated to DC; this is a noise-averaging
 *      lock-in integrator
 *   4. divide the accumulators by SAMPLES_PER_FREQ (arithmetic shift)
 *      and hand 14-bit signed I/Q to the shared CORDIC
 *   5. capture |Z| (16-bit unsigned-ish, fits without saturation per
 *      §3.1 max-input analysis) and ∠Z (Q4.12) into per-freq
 *      registers
 *
 * After all three freqs done: assert hw_is_wr for one cycle so
 * reg_bank latches Z_MAG_x and Z_PHASE_x atomically, then pulse is_done
 * and return to S_IDLE.
 *
 * Accumulator analysis (SAMPLES_PER_FREQ = 32, ADC 14-bit signed):
 *   max |sum| = 32 × 8192 = 262144 → 20-bit signed accumulator
 *   ÷32 (>>> 5) → 14-bit signed average, no saturation needed
 *
 * Width contracts:
 *   adc_data       14-bit signed (centered at 0; ADC controller
 *                  handles any unsigned→signed conversion)
 *   cordic_i/q_in  14-bit signed
 *   cordic_mag     18-bit (always non-negative); truncate to 16-bit
 *                  for register — max value K·√(I²+Q²) ≈ 19115 fits
 *   cordic_phase   16-bit signed Q4.12
 *
 * State count: 11 (4-bit encoded). FSM-state coverage target: 100%
 * (per SPEC §9.1 VER-RTL-003).
 */

`default_nettype none

module is_fsm #(
    parameter SAMPLES_PER_FREQ   = 32,
    parameter SETTLE_10K_CYCLES  = 100,
    parameter SETTLE_30K_CYCLES  = 33,
    parameter SETTLE_100K_CYCLES = 10,
    parameter [2:0] ADC_MUX_I    = 3'd0,
    parameter [2:0] ADC_MUX_Q    = 3'd1,
    parameter ADC_TIMEOUT        = 1024   // max clk cycles to wait for adc_valid
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Scheduler interface
    input  wire                  is_sweep_start,
    output reg                   is_done,

    // DDS control
    output reg  [1:0]            freq_sel,
    output reg                   dds_enable,

    // ADC controller
    output reg                   adc_start,
    output reg  [2:0]            adc_mux_sel,
    input  wire                  adc_valid,
    input  wire signed [13:0]    adc_data,

    // CORDIC
    output reg                   cordic_start,
    output reg  signed [13:0]    cordic_i_in,
    output reg  signed [13:0]    cordic_q_in,
    input  wire                  cordic_done,
    input  wire signed [17:0]    cordic_mag,
    input  wire signed [15:0]    cordic_phase,

    // reg_bank hardware write ports
    output reg                   hw_is_wr,
    output reg  [15:0]           hw_z_mag_10k,
    output reg  [15:0]           hw_z_phase_10k,
    output reg  [15:0]           hw_z_mag_30k,
    output reg  [15:0]           hw_z_phase_30k,
    output reg  [15:0]           hw_z_mag_100k,
    output reg  [15:0]           hw_z_phase_100k,

    // Fault flag: ADC never returned a sample within ADC_TIMEOUT
    // (electrode fault / stuck ADC) -- SPEC REQ-IS-012. Persists until
    // the next sweep starts.
    output reg                   is_error
);

    // ============================================================
    // States
    // ============================================================
    localparam [3:0]
        S_IDLE        = 4'd0,
        S_FREQ_START  = 4'd1,
        S_SETTLE      = 4'd2,
        S_ADC_I       = 4'd3,
        S_ADC_I_WAIT  = 4'd4,
        S_ADC_Q       = 4'd5,
        S_ADC_Q_WAIT  = 4'd6,
        S_CORDIC      = 4'd7,
        S_CORDIC_WAIT = 4'd8,
        S_STORE       = 4'd9,
        S_DONE        = 4'd10;

    reg [3:0]           state;
    reg [1:0]           freq_idx;
    reg [5:0]           sample_count;
    reg [9:0]           settle_count;
    reg signed [19:0]   i_acc;
    reg signed [19:0]   q_acc;
    reg [11:0]          adc_wait_count;   // watchdog for adc_valid

    // ============================================================
    // Settle target per freq (combinational LUT)
    // ============================================================
    reg [9:0] settle_target;
    always @(*) begin
        case (freq_idx)
            2'd0:    settle_target = SETTLE_10K_CYCLES[9:0];
            2'd1:    settle_target = SETTLE_30K_CYCLES[9:0];
            2'd2:    settle_target = SETTLE_100K_CYCLES[9:0];
            default: settle_target = SETTLE_10K_CYCLES[9:0];
        endcase
    end

    // ============================================================
    // 14-bit signed I/Q averages
    //   i_acc / SAMPLES_PER_FREQ via arithmetic right shift.
    //   At SAMPLES_PER_FREQ = 32 we shift by 5; the bit slice
    //   [18:5] gives exactly that for the 20-bit accumulator,
    //   sign included, with no saturation needed.
    // ============================================================
    wire signed [13:0] i_avg = i_acc[18:5];
    wire signed [13:0] q_avg = q_acc[18:5];

    // ============================================================
    // FSM + datapath
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            freq_idx        <= 2'd0;
            sample_count    <= 6'd0;
            settle_count    <= 10'd0;
            i_acc           <= 20'sd0;
            q_acc           <= 20'sd0;
            adc_wait_count  <= 12'd0;
            is_error        <= 1'b0;
            freq_sel        <= 2'b11;   // halted (matches DDS reset default)
            dds_enable      <= 1'b0;
            adc_start       <= 1'b0;
            adc_mux_sel     <= 3'd0;
            cordic_start    <= 1'b0;
            cordic_i_in     <= 14'sd0;
            cordic_q_in     <= 14'sd0;
            is_done         <= 1'b0;
            hw_is_wr        <= 1'b0;
            hw_z_mag_10k    <= 16'd0;
            hw_z_phase_10k  <= 16'd0;
            hw_z_mag_30k    <= 16'd0;
            hw_z_phase_30k  <= 16'd0;
            hw_z_mag_100k   <= 16'd0;
            hw_z_phase_100k <= 16'd0;
        end else begin
            // Single-cycle defaults
            adc_start    <= 1'b0;
            cordic_start <= 1'b0;
            is_done      <= 1'b0;
            hw_is_wr     <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (is_sweep_start) begin
                        freq_idx       <= 2'd0;
                        is_error       <= 1'b0;   // clear fault on new sweep
                        adc_wait_count <= 12'd0;
                        state          <= S_FREQ_START;
                    end
                end

                S_FREQ_START: begin
                    freq_sel     <= freq_idx;     // 0/1/2 → DDS picks step
                    dds_enable   <= 1'b1;
                    sample_count <= 6'd0;
                    settle_count <= 10'd0;
                    i_acc        <= 20'sd0;
                    q_acc        <= 20'sd0;
                    state        <= S_SETTLE;
                end

                S_SETTLE: begin
                    if (settle_count >= settle_target - 10'd1) begin
                        settle_count <= 10'd0;
                        state        <= S_ADC_I;
                    end else begin
                        settle_count <= settle_count + 10'd1;
                    end
                end

                S_ADC_I: begin
                    adc_mux_sel    <= ADC_MUX_I;
                    adc_start      <= 1'b1;
                    adc_wait_count <= 12'd0;
                    state          <= S_ADC_I_WAIT;
                end

                S_ADC_I_WAIT: begin
                    if (adc_valid) begin
                        // 14-bit signed → 20-bit sign-extend, add
                        i_acc <= i_acc +
                                 {{6{adc_data[13]}}, adc_data};
                        state <= S_ADC_Q;
                    end else if (adc_wait_count >= ADC_TIMEOUT[11:0] - 12'd1) begin
                        is_error <= 1'b1;   // ADC/electrode fault
                        state    <= S_DONE;
                    end else begin
                        adc_wait_count <= adc_wait_count + 12'd1;
                    end
                end

                S_ADC_Q: begin
                    adc_mux_sel    <= ADC_MUX_Q;
                    adc_start      <= 1'b1;
                    adc_wait_count <= 12'd0;
                    state          <= S_ADC_Q_WAIT;
                end

                S_ADC_Q_WAIT: begin
                    if (adc_valid) begin
                        q_acc <= q_acc +
                                 {{6{adc_data[13]}}, adc_data};
                        if (sample_count == SAMPLES_PER_FREQ - 1) begin
                            sample_count <= 6'd0;
                            state        <= S_CORDIC;
                        end else begin
                            sample_count <= sample_count + 6'd1;
                            state        <= S_ADC_I;
                        end
                    end else if (adc_wait_count >= ADC_TIMEOUT[11:0] - 12'd1) begin
                        is_error <= 1'b1;   // ADC/electrode fault
                        state    <= S_DONE;
                    end else begin
                        adc_wait_count <= adc_wait_count + 12'd1;
                    end
                end

                S_CORDIC: begin
                    cordic_i_in  <= i_avg;
                    cordic_q_in  <= q_avg;
                    cordic_start <= 1'b1;
                    state        <= S_CORDIC_WAIT;
                end

                S_CORDIC_WAIT: begin
                    if (cordic_done) begin
                        case (freq_idx)
                            2'd0: begin
                                hw_z_mag_10k    <= cordic_mag[15:0];
                                hw_z_phase_10k  <= cordic_phase;
                            end
                            2'd1: begin
                                hw_z_mag_30k    <= cordic_mag[15:0];
                                hw_z_phase_30k  <= cordic_phase;
                            end
                            2'd2: begin
                                hw_z_mag_100k   <= cordic_mag[15:0];
                                hw_z_phase_100k <= cordic_phase;
                            end
                            default: ;  // unreachable
                        endcase

                        if (freq_idx == 2'd2) begin
                            state <= S_STORE;
                        end else begin
                            freq_idx <= freq_idx + 2'd1;
                            state    <= S_FREQ_START;
                        end
                    end
                end

                S_STORE: begin
                    hw_is_wr <= 1'b1;
                    state    <= S_DONE;
                end

                S_DONE: begin
                    is_done    <= 1'b1;
                    dds_enable <= 1'b0;
                    freq_sel   <= 2'b11;   // halt DDS
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
