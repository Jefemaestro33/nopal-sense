/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * sensor_read_controller.v -- consolidated sensor read pipeline
 * (SPEC §3.2 SC-IN-001, ARCHITECTURE §5.1 Scenario A + §3.2 pipeline).
 *
 * Flow:  raw ADC MUX sweep  ->  calibration  ->  per-channel moving
 *        average (N=4)  ->  packed sensor registers.
 *
 * 1. RAW READ: cycle the analog MUX across the sensor channels and
 *    capture each 14-bit ADC result as an 8-bit field (adc_data[13:6]):
 *      0 H10  1 H20  2 H30  3 TEMP  4 BATTERY
 *    EC_FREQ comes from pulse_counter via ec_count (TBD integration).
 *
 * 2. CALIBRATE: a single shared Q8.8 MAC (ARCHITECTURE D-DP-003,
 *    time-multiplexed) applies  y = a*x + b - alpha*(T - Tref)  to each
 *    channel, with T taken from the temperature channel. The raw reading
 *    (adc_data[13:6], 0..127 for a positive single-ended ADC) is fed as
 *    Q8.8 (raw << 8); the default coefficients (a=1, b=0, alpha=0) give
 *    an identity pass-through. The stored field is unsigned 0..127: the
 *    MAC saturates a result above the Q8.8 range to the +127.996 rail
 *    and the unsigned conversion clamps a negative result to 0, so an
 *    out-of-range gain reads as full-scale, never wrapping to 0.
 *
 * The ADC is shared with is_fsm (ARCHITECTURE D-IS-005); arbitration is
 * done at nopal_sense_top using this module's `busy` output.
 *
 * Fault policy (REQ-IS-012, matches is_fsm): a per-conversion watchdog
 * (ADC_TIMEOUT) raises is_error on a stuck ADC / faulted channel; the
 * read aborts WITHOUT committing, so the last-good registers are kept.
 */

`default_nettype none

module sensor_read_controller #(
    parameter ADC_TIMEOUT = 1024
)(
    input  wire               clk,
    input  wire               rst_n,

    input  wire               sensor_read_start,
    output reg                sensor_read_done,

    // Shared ADC interface (arbitrated at top level)
    output reg                adc_start,
    output reg  [2:0]         adc_mux_sel,
    input  wire               adc_valid,
    input  wire signed [13:0] adc_data,

    // EC frequency count (from pulse_counter)
    input  wire [15:0]        ec_count,

    // Calibration coefficients (Q8.8, from reg_bank)
    input  wire signed [15:0] cal_a,
    input  wire signed [15:0] cal_b,
    input  wire signed [15:0] cal_alpha,
    input  wire signed [15:0] cal_tref,

    // reg_bank hardware sensor write port
    output reg                hw_sensor_wr,
    output reg  [15:0]        h10_h20,
    output reg  [15:0]        h30_temp,
    output reg  [15:0]        ec_freq,
    output reg  [15:0]        battery,

    output wire               busy,      // 1 while this owns the ADC
    output reg                is_error   // ADC/channel fault during read
);

    localparam [2:0] N_CHAN = 3'd5;

    localparam [2:0]
        S_IDLE      = 3'd0,
        S_CONV      = 3'd1,
        S_WAIT      = 3'd2,
        S_PROC      = 3'd3,   // launch calibration of channel proc_ch
        S_PROC_CAL  = 3'd4,   // calibration done -> feed moving average
        S_PROC_AVG  = 3'd5,   // capture averaged result
        S_DONE      = 3'd6;

    reg [2:0]  state;
    reg [2:0]  ch;            // raw-read channel
    reg [2:0]  proc_ch;       // calibration channel
    reg [11:0] wait_cnt;

    // raw (pre-calibration) per-channel readings
    reg [7:0]  v_h10, v_h20, v_h30, v_temp, v_batt;
    // calibrated per-channel results
    reg [7:0]  r_h10, r_h20, r_h30, r_temp, r_batt;

    assign busy = (state != S_IDLE);

    wire [7:0] sample8 = adc_data[13:6];

    // ============================================================
    // Shared calibration MAC (time-multiplexed across channels)
    // ============================================================
    reg                cal_start;
    reg  [7:0]          raw_sel;
    wire signed [15:0]  cal_x = {raw_sel, 8'd0};   // raw as Q8.8
    wire signed [15:0]  cal_t = {v_temp,  8'd0};   // temperature as Q8.8
    wire signed [15:0]  cal_y;
    wire                cal_done;

    always @(*) begin
        case (proc_ch)
            3'd0:    raw_sel = v_h10;
            3'd1:    raw_sel = v_h20;
            3'd2:    raw_sel = v_h30;
            3'd3:    raw_sel = v_temp;
            3'd4:    raw_sel = v_batt;
            default: raw_sel = 8'd0;
        endcase
    end

    // unsigned 8-bit field: negative -> 0 (a positive overflow is
    // already saturated to 127 by the calibration MAC)
    wire [7:0] cal8 = cal_y[15] ? 8'd0 : cal_y[15:8];

    calibration u_cal (
        .clk(clk), .rst_n(rst_n),
        .start(cal_start),
        .x(cal_x), .t(cal_t),
        .cal_a(cal_a), .cal_b(cal_b),
        .cal_alpha(cal_alpha), .cal_tref(cal_tref),
        .y(cal_y), .done(cal_done)
    );

    // ============================================================
    // Per-channel moving average (ARCHITECTURE D-DP-002). N=4 window
    // (a window-select register is deferred to v1.1). Each channel keeps
    // its own history: the calibrated value of channel proc_ch is pushed
    // in S_PROC_CAL and the averaged result is read back in S_PROC_AVG.
    // ============================================================
    wire [4:0]         mavg_sv = (state == S_PROC_CAL && cal_done)
                                 ? (5'd1 << proc_ch) : 5'd0;
    wire signed [15:0] mavg_in = {8'd0, cal8};
    wire signed [15:0] mavg_out [0:4];

    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_mavg
            moving_avg u_mavg (
                .clk(clk), .rst_n(rst_n),
                .enable(1'b1),
                .window_sel(2'd0),          // N = 4
                .sample_valid(mavg_sv[gi]),
                .sample_in(mavg_in),
                .avg_out(mavg_out[gi])
            );
        end
    endgenerate

    // averaged result for the channel being processed (>=0 by construction)
    wire [7:0] avg8 = mavg_out[proc_ch][15] ? 8'd0 : mavg_out[proc_ch][7:0];

    // ============================================================
    // FSM
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            ch               <= 3'd0;
            proc_ch          <= 3'd0;
            wait_cnt         <= 12'd0;
            adc_start        <= 1'b0;
            adc_mux_sel      <= 3'd0;
            cal_start        <= 1'b0;
            sensor_read_done <= 1'b0;
            hw_sensor_wr     <= 1'b0;
            is_error         <= 1'b0;
            h10_h20          <= 16'd0;
            h30_temp         <= 16'd0;
            ec_freq          <= 16'd0;
            battery          <= 16'd0;
            v_h10 <= 8'd0; v_h20 <= 8'd0; v_h30 <= 8'd0;
            v_temp <= 8'd0; v_batt <= 8'd0;
            r_h10 <= 8'd0; r_h20 <= 8'd0; r_h30 <= 8'd0;
            r_temp <= 8'd0; r_batt <= 8'd0;
        end else begin
            // single-cycle defaults
            adc_start        <= 1'b0;
            cal_start        <= 1'b0;
            sensor_read_done <= 1'b0;
            hw_sensor_wr     <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (sensor_read_start) begin
                        ch       <= 3'd0;
                        is_error <= 1'b0;
                        wait_cnt <= 12'd0;
                        state    <= S_CONV;
                    end
                end

                // ---- raw ADC MUX sweep ----
                S_CONV: begin
                    adc_mux_sel <= ch;
                    adc_start   <= 1'b1;
                    wait_cnt    <= 12'd0;
                    state       <= S_WAIT;
                end

                S_WAIT: begin
                    if (adc_valid) begin
                        case (ch)
                            3'd0: v_h10  <= sample8;
                            3'd1: v_h20  <= sample8;
                            3'd2: v_h30  <= sample8;
                            3'd3: v_temp <= sample8;
                            3'd4: v_batt <= sample8;
                            default: ;
                        endcase
                        if (ch == N_CHAN - 3'd1) begin
                            proc_ch <= 3'd0;
                            state   <= S_PROC;     // all raw captured
                        end else begin
                            ch    <= ch + 3'd1;
                            state <= S_CONV;
                        end
                    end else if (wait_cnt >= ADC_TIMEOUT[11:0] - 12'd1) begin
                        is_error <= 1'b1;
                        state    <= S_DONE;        // abort, do not commit
                    end else begin
                        wait_cnt <= wait_cnt + 12'd1;
                    end
                end

                // ---- calibrate each channel (shared MAC) ----
                S_PROC: begin
                    cal_start <= 1'b1;             // x/t selected by proc_ch
                    state     <= S_PROC_CAL;
                end

                S_PROC_CAL: begin
                    // cal_done: cal8 is pushed into this channel's moving
                    // average via mavg_sv (combinational); read it next cycle.
                    if (cal_done) state <= S_PROC_AVG;
                end

                S_PROC_AVG: begin
                    case (proc_ch)
                        3'd0: r_h10  <= avg8;
                        3'd1: r_h20  <= avg8;
                        3'd2: r_h30  <= avg8;
                        3'd3: r_temp <= avg8;
                        3'd4: r_batt <= avg8;
                        default: ;
                    endcase
                    if (proc_ch == N_CHAN - 3'd1) begin
                        state <= S_DONE;
                    end else begin
                        proc_ch <= proc_ch + 3'd1;
                        state   <= S_PROC;
                    end
                end

                S_DONE: begin
                    // Commit only a complete, fault-free read. On a fault
                    // keep the last-good registers (matches is_fsm).
                    if (!is_error) begin
                        h10_h20      <= {r_h20, r_h10};
                        h30_temp     <= {r_temp, r_h30};
                        ec_freq      <= ec_count;
                        battery      <= {8'd0, r_batt};
                        hw_sensor_wr <= 1'b1;
                    end
                    sensor_read_done <= 1'b1;       // always unblock scheduler
                    state            <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
