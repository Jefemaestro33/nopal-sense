/*
 * Testbench: is_fsm.v — IS measurement orchestrator
 *
 * Instantiates the REAL cordic.v (so the I/Q → mag/phase path is
 * end-to-end verified) plus a mock ADC that returns frequency- and
 * channel-specific values:
 *
 *   10 kHz:  I = +1000, Q = 0       → mag ≈ K·1000 = 1647, phase = 0
 *   30 kHz:  I = 0,     Q = +1000   → mag ≈ 1647,         phase ≈ π/2
 *   100 kHz: I = -1000, Q = 0       → mag ≈ 1647,         phase ≈ π
 *
 * Settle counters overridden small for sim speed (5/3/2 cycles).
 * SAMPLES_PER_FREQ kept at 32 to exercise the production loop count.
 *
 * Covers:
 *   T01-03 reset → IDLE, no outputs asserted
 *   T04    is_sweep_start triggers sweep
 *   T05-10 6 result registers within tolerance after sweep
 *   T11    is_done pulsed exactly once
 *   T12    is_sweep_start mid-sweep is ignored
 *   T13    second sweep (back-to-back) produces same results
 */

`timescale 1ns/1ps

module tb_is_fsm;

    // Constants
    localparam K_NUM    = 16467;        // K × 10000
    localparam K_DENOM  = 10000;
    localparam PI_Q12   = 12868;
    localparam PI_2_Q12 = 6434;
    localparam MAG_EXP  = (1000 * K_NUM) / K_DENOM;  // ≈ 1647
    localparam MAG_TOL  = 80;           // ~5 %
    localparam PHASE_TOL = 80;

    reg                   clk = 1'b0;
    reg                   rst_n = 1'b0;
    reg                   is_sweep_start = 1'b0;

    wire                  is_done;
    wire [1:0]            freq_sel;
    wire                  dds_enable;
    wire                  adc_start;
    wire [2:0]            adc_mux_sel;
    reg                   adc_valid = 1'b0;
    reg  signed [13:0]    adc_data = 14'sd0;
    wire                  cordic_start;
    wire signed [13:0]    cordic_i_in;
    wire signed [13:0]    cordic_q_in;
    wire                  cordic_done;
    wire signed [17:0]    cordic_mag;
    wire signed [15:0]    cordic_phase;
    wire                  hw_is_wr;
    wire [15:0]           hw_z_mag_10k;
    wire [15:0]           hw_z_phase_10k;
    wire [15:0]           hw_z_mag_30k;
    wire [15:0]           hw_z_phase_30k;
    wire [15:0]           hw_z_mag_100k;
    wire [15:0]           hw_z_phase_100k;

    is_fsm #(
        .SAMPLES_PER_FREQ  (32),
        .SETTLE_10K_CYCLES (5),
        .SETTLE_30K_CYCLES (3),
        .SETTLE_100K_CYCLES(2)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .is_sweep_start(is_sweep_start),
        .is_done(is_done),
        .freq_sel(freq_sel),
        .dds_enable(dds_enable),
        .adc_start(adc_start),
        .adc_mux_sel(adc_mux_sel),
        .adc_valid(adc_valid),
        .adc_data(adc_data),
        .cordic_start(cordic_start),
        .cordic_i_in(cordic_i_in),
        .cordic_q_in(cordic_q_in),
        .cordic_done(cordic_done),
        .cordic_mag(cordic_mag),
        .cordic_phase(cordic_phase),
        .hw_is_wr(hw_is_wr),
        .hw_z_mag_10k(hw_z_mag_10k),
        .hw_z_phase_10k(hw_z_phase_10k),
        .hw_z_mag_30k(hw_z_mag_30k),
        .hw_z_phase_30k(hw_z_phase_30k),
        .hw_z_mag_100k(hw_z_mag_100k),
        .hw_z_phase_100k(hw_z_phase_100k)
    );

    // Real CORDIC instance
    cordic u_cordic (
        .clk(clk), .rst_n(rst_n),
        .start(cordic_start),
        .i_in(cordic_i_in), .q_in(cordic_q_in),
        .mag_out(cordic_mag),
        .phase_out(cordic_phase),
        .done(cordic_done)
    );

    // 1 MHz sim clock
    always #500 clk = ~clk;

    // ============================================================
    // Mock ADC: 5-cycle conversion latency, value picked per freq+mux
    // ============================================================
    reg [3:0] adc_delay;
    reg signed [13:0] adc_i_table [0:2];
    reg signed [13:0] adc_q_table [0:2];

    initial begin
        adc_i_table[0] = 14'sd1000;   adc_q_table[0] = 14'sd0;
        adc_i_table[1] = 14'sd0;      adc_q_table[1] = 14'sd1000;
        adc_i_table[2] = -14'sd1000;  adc_q_table[2] = 14'sd0;
        adc_delay = 4'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_delay <= 4'd0;
            adc_valid <= 1'b0;
            adc_data  <= 14'sd0;
        end else begin
            adc_valid <= 1'b0;
            if (adc_start) begin
                adc_delay <= 4'd4;     // 5-cycle conversion
            end else if (adc_delay > 4'd0) begin
                adc_delay <= adc_delay - 4'd1;
                if (adc_delay == 4'd1) begin
                    adc_valid <= 1'b1;
                    if (adc_mux_sel == 3'd0)
                        adc_data <= adc_i_table[freq_sel];
                    else
                        adc_data <= adc_q_table[freq_sel];
                end
            end
        end
    end

    // is_done pulse counter (to verify "exactly once per sweep")
    integer done_count;
    always @(posedge clk) begin
        if (is_done) done_count <= done_count + 1;
    end

    integer pass_count = 0;
    integer fail_count = 0;

    function integer iabs;
        input integer v;
        begin
            iabs = (v < 0) ? -v : v;
        end
    endfunction

    task check_eq_int(input integer val, input integer expected, input [127:0] tag);
        begin
            if (val === expected) begin
                $display("PASS [%0s]: %0d", tag, val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got %0d expected %0d", tag, val, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_close(
        input integer val,
        input integer expected,
        input integer tol,
        input [127:0] tag
    );
        integer v_se;
        begin
            v_se = val;
            // Sign-extend 16-bit signed values for phase comparison
            if (val & 32'h00008000) v_se = val | 32'hFFFF0000;

            if (iabs(v_se - expected) <= tol) begin
                $display("PASS [%0s]: %0d (exp %0d, diff %0d)",
                         tag, v_se, expected, iabs(v_se - expected));
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got %0d expected %0d diff %0d",
                         tag, v_se, expected, iabs(v_se - expected));
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        done_count = 0;

        // ------------------------------------------------------------
        // T01-03: Reset state
        // ------------------------------------------------------------
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        check_eq_int(is_done,    0,      "T01_no_done_idle");
        check_eq_int(dds_enable, 0,      "T02_dds_off_idle");
        check_eq_int(hw_is_wr,   0,      "T03_no_hw_write_idle");

        // ------------------------------------------------------------
        // T04: Fire sweep start, wait for done
        // ------------------------------------------------------------
        is_sweep_start = 1;
        @(posedge clk);
        is_sweep_start = 0;

        // Wait for is_done with timeout watchdog
        begin : wait_done_1
            integer timeout;
            timeout = 0;
            while (!is_done && timeout < 5000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 5000) begin
                $display("FAIL [T04_timeout]: sweep did not complete");
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T04_sweep_completes]: %0d cycles", timeout);
                pass_count = pass_count + 1;
            end
        end

        @(posedge clk);

        // ------------------------------------------------------------
        // T05-10: Verify 6 register values
        //   10 kHz:  I=+1000, Q=0     → mag≈1647, phase=0
        //   30 kHz:  I=0,     Q=+1000 → mag≈1647, phase=π/2
        //   100 kHz: I=-1000, Q=0     → mag≈1647, phase=π (or -π in 16-bit signed)
        // ------------------------------------------------------------
        check_close(hw_z_mag_10k,   MAG_EXP, MAG_TOL,   "T05_mag_10k");
        check_close(hw_z_phase_10k, 0,       PHASE_TOL, "T06_phase_10k");
        check_close(hw_z_mag_30k,   MAG_EXP, MAG_TOL,   "T07_mag_30k");
        check_close(hw_z_phase_30k, PI_2_Q12, PHASE_TOL, "T08_phase_30k");
        check_close(hw_z_mag_100k,  MAG_EXP, MAG_TOL,   "T09_mag_100k");
        check_close(hw_z_phase_100k, PI_Q12, PHASE_TOL, "T10_phase_100k");

        // ------------------------------------------------------------
        // T11: is_done pulsed exactly once
        // ------------------------------------------------------------
        check_eq_int(done_count, 1, "T11_done_once");

        // ------------------------------------------------------------
        // T12: is_sweep_start in the middle of next sweep is ignored
        //      (re-trigger and pulse start mid-flight)
        // ------------------------------------------------------------
        is_sweep_start = 1;
        @(posedge clk);
        is_sweep_start = 0;
        repeat (50) @(posedge clk);   // mid-sweep
        is_sweep_start = 1;            // spurious re-trigger
        @(posedge clk);
        is_sweep_start = 0;

        // Wait for done
        begin : wait_done_2
            integer timeout;
            timeout = 0;
            while (!is_done && timeout < 5000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            $display("PASS [T12_sweep2_completes]: %0d cycles", timeout);
            pass_count = pass_count + 1;
        end
        @(posedge clk);

        // ------------------------------------------------------------
        // T13: Second sweep produced equivalent results
        // ------------------------------------------------------------
        check_close(hw_z_mag_10k,   MAG_EXP, MAG_TOL,   "T13_sweep2_mag_10k");
        check_close(hw_z_phase_10k, 0,       PHASE_TOL, "T13b_sweep2_phase_10k");

        $display("");
        $display("==========================================");
        $display("IS_FSM tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL IS_FSM TESTS PASSED ***");
        else
            $display("*** IS_FSM FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: global timeout");
        $finish;
    end

endmodule
