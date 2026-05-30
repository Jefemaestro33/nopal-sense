/*
 * Testbench: wake_timer.v
 *
 * Covers:
 *  T01-02 reset → counter=0, no fire
 *  T03    disabled chip holds counter at 0
 *  T04-05 period 0 (1 min) fires after CYCLES_PER_MIN, repeats
 *  T06    period 1 (5 min) fires after 5×CYCLES_PER_MIN
 *  T07    period 3 (1 hr) fires after 60×CYCLES_PER_MIN
 *  T08    reserved code (6-15) defaults to 1 hr (60×CYCLES_PER_MIN)
 *  T09    ALERT overrides any period to 1 min (immediate cadence)
 *  T10    ALERT clears → returns to original cadence
 *  T11    Cadence shortened mid-count → fires immediately on next edges
 *  T12    Cadence lengthened mid-count → no spurious fire
 *
 * Sim accelerator: CYCLES_PER_MIN overridden to 10 so a "minute" is
 * 10 clk edges. ALERT_PERIOD_MIN = 1 → alert target = 10. 1 hr = 600
 * cycles in sim.
 *
 * Run via Makefile: make test_wake_timer
 */

`timescale 1ns/1ps

module tb_wake_timer;

    reg         clk_32k = 1'b0;
    reg         rst_n   = 1'b0;
    reg         chip_enable   = 1'b0;
    reg  [3:0]  period_sel    = 4'd0;
    reg         alert_latched = 1'b0;
    wire        wake_pulse;

    // Sim-fast parameters: 10 cycles per "minute"
    localparam SIM_CPM = 10;

    wake_timer #(.CYCLES_PER_MIN(SIM_CPM), .ALERT_PERIOD_MIN(1)) dut (
        .clk_32k(clk_32k),
        .rst_n(rst_n),
        .chip_enable(chip_enable),
        .period_sel(period_sel),
        .alert_latched(alert_latched),
        .wake_pulse(wake_pulse)
    );

    // 1 MHz sim clock (treated as "32k" with the scaling above)
    always #500 clk_32k = ~clk_32k;

    integer pass_count = 0;
    integer fail_count = 0;

    // Count wake pulses observed in an interval
    integer wake_observed;
    always @(posedge clk_32k) begin
        if (wake_pulse) wake_observed <= wake_observed + 1;
    end

    task expect_wake_count(input integer expected, input [127:0] tag);
        begin
            if (wake_observed === expected) begin
                $display("PASS [%0s]: wakes=%0d", tag, wake_observed);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: wakes=%0d expected=%0d",
                         tag, wake_observed, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_eq(input val, input expected, input [127:0] tag);
        begin
            if (val === expected) begin
                $display("PASS [%0s]: %0b", tag, val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got %0b expected %0b", tag, val, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk_32k);
        end
    endtask

    // Sync latency for inputs main->32k: 2 clk_32k edges.
    localparam SYNC_LATENCY = 3;  // 2 + 1 slack

    initial begin
        wake_observed = 0;

        // ----------------------------------------------------------------
        // T01-02: Reset
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);
        check_eq(wake_pulse, 1'b0, "T01_no_wake_at_reset");
        expect_wake_count(0, "T02_no_wakes_yet");

        // ----------------------------------------------------------------
        // T03: Disabled chip — no fires for many cycles
        // ----------------------------------------------------------------
        chip_enable = 1'b0;
        period_sel  = 4'd0;
        wait_cycles(50);
        expect_wake_count(0, "T03_disabled_no_fire");

        // ----------------------------------------------------------------
        // T04: Enable + period 0 (1 min = 10 cycles) → 1 fire
        // ----------------------------------------------------------------
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd0;
        wait_cycles(SYNC_LATENCY);   // settle CDC
        wait_cycles(SIM_CPM + 2);    // 10 cycles + slack → exactly 1 fire
        expect_wake_count(1, "T04_1min_fires_once");

        // ----------------------------------------------------------------
        // T05: Continue → 2nd fire after another 1-min
        // ----------------------------------------------------------------
        wait_cycles(SIM_CPM);
        expect_wake_count(2, "T05_1min_fires_again");

        // ----------------------------------------------------------------
        // T06: period 1 (5 min = 50 cycles)
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd1;
        wait_cycles(SYNC_LATENCY);
        wait_cycles(5 * SIM_CPM + 2);
        expect_wake_count(1, "T06_5min_one_fire");

        // ----------------------------------------------------------------
        // T07: period 3 (1 hr = 600 cycles)
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd3;
        wait_cycles(SYNC_LATENCY);
        wait_cycles(60 * SIM_CPM + 2);
        expect_wake_count(1, "T07_1hr_one_fire");

        // ----------------------------------------------------------------
        // T08: Reserved code (e.g. 4'd7) defaults to 1 hr (60 × SIM_CPM)
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd7;          // reserved
        wait_cycles(SYNC_LATENCY);
        // Should NOT fire before 1 hr - 1
        wait_cycles(60 * SIM_CPM - 5);
        expect_wake_count(0, "T08a_reserved_no_early_fire");
        // Should fire by 1 hr + 5
        wait_cycles(10);
        expect_wake_count(1, "T08b_reserved_fires_at_1hr");

        // ----------------------------------------------------------------
        // T09: ALERT override forces 1-min cadence
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd5;           // 24 hr (huge)
        wait_cycles(SYNC_LATENCY);
        alert_latched = 1'b1;
        wait_cycles(SYNC_LATENCY);
        wait_cycles(SIM_CPM + 3);     // ~10 cycles → fire
        expect_wake_count(1, "T09_alert_fires_1min");

        // ----------------------------------------------------------------
        // T10: ALERT clears → returns to 24 hr cadence (no quick fires)
        // ----------------------------------------------------------------
        wake_observed = 0;
        alert_latched = 1'b0;
        wait_cycles(SYNC_LATENCY);
        wait_cycles(3 * SIM_CPM);     // 30 cycles - no fire expected (24hr=14400)
        expect_wake_count(0, "T10_post_alert_quiet");

        // ----------------------------------------------------------------
        // T11: Cadence shortened mid-count fires immediately
        //   Start with 1 hr (600), wait 300 cycles, switch to 1 min (10)
        //   → counter >> target → fires within sync latency
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd3;            // 1 hr
        wait_cycles(SYNC_LATENCY);
        wait_cycles(300);              // halfway to 1 hr
        period_sel  = 4'd0;            // 1 min
        wait_cycles(SYNC_LATENCY + 3); // sync + fire
        expect_wake_count(1, "T11_shortened_fires_now");

        // ----------------------------------------------------------------
        // T12: Cadence lengthened mid-count: NO spurious fire
        //   Start with 1 min (10), wait until counter ~ 5, switch to 1 hr.
        //   Wait some cycles - should NOT fire (counter < new target).
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wake_observed = 0;
        chip_enable = 1'b1;
        period_sel  = 4'd0;            // 1 min
        wait_cycles(SYNC_LATENCY);
        wait_cycles(5);                // halfway
        period_sel  = 4'd3;            // 1 hr
        wait_cycles(50);               // way past the old 1-min target
        // counter should be ~50-60 < 600 (1 hr) → no fire
        expect_wake_count(0, "T12_lengthened_no_fire");

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("");
        $display("==========================================");
        $display("Wake_timer tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL WAKE_TIMER TESTS PASSED ***");
        else
            $display("*** WAKE_TIMER FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL: timeout reached");
        $finish;
    end

endmodule
