/*
 * Testbench: scheduler.v (refactored)
 *
 * Covers:
 *  T01-04 reset state + status_ready + power off
 *  T05    chip disabled ignores wake_pulse
 *  T06-09 NORMAL cycle without IS (no CTRL[8])
 *  T10-12 NORMAL cycle with IS in normal (CTRL[8]=1)
 *  T13-15 VALIDATION goes through WARMUP (BUG-1 fix)
 *  T16-19 ALERT as level modifier — INT_OUT level, mode override,
 *         FSM keeps cycling, ack clears (BUG-2 fix)
 *  T20-21 DEBUG priority over alert (DEBUG > ALERT in mode mapping)
 *  T22-23 VALIDATION priority over alert (VALIDATION > ALERT)
 *  T24    trig_clear_state mid-cycle forces DEEP_SLEEP
 *  T25    trig_is_sweep from sleep latches into S_IS_SWEEP even with
 *         CTRL[8]=0
 *  T26    alert_active going low alone does NOT clear alert_latched
 *         (ack_pulse is required)
 *
 * Run via Makefile: make test_scheduler
 *
 * Tag strings are ASCII-only short labels to avoid the 256-bit pack
 * truncation we saw in the previous revision.
 */

`timescale 1ns/1ps

module tb_scheduler;

    reg         clk = 1'b0;
    reg         rst_n = 1'b0;

    reg  [15:0] ctrl_reg         = 16'h0000;
    reg  [15:0] trigger_reg      = 16'h0000;
    reg  [15:0] sched_warmup_reg = 16'h0001;  // 1 ms

    reg         wake_pulse       = 1'b0;
    reg         alert_active     = 1'b0;
    reg         ack_pulse        = 1'b0;
    reg         debug_enter      = 1'b0;
    reg         debug_exit       = 1'b0;

    reg         sensor_read_done = 1'b0;
    reg         is_done          = 1'b0;
    reg         self_test_done   = 1'b0;

    wire        sensor_read_start;
    wire        is_sweep_start;
    wire        self_test_start;
    wire        power_analog_en;
    wire        power_digital_en;
    wire        int_out_n;
    wire [2:0]  current_mode;
    wire        status_ready, status_measuring, status_alert_active, status_is_done;

    // DUT — fast sim: 10 cycles per ms
    scheduler #(.CLK_FREQ_HZ(1_000_000), .CYCLES_PER_MS(10)) dut (
        .clk(clk), .rst_n(rst_n),
        .ctrl_reg(ctrl_reg),
        .trigger_reg(trigger_reg),
        .sched_warmup_reg(sched_warmup_reg),
        .wake_pulse(wake_pulse),
        .alert_active(alert_active),
        .ack_pulse(ack_pulse),
        .debug_enter(debug_enter),
        .debug_exit(debug_exit),
        .sensor_read_done(sensor_read_done),
        .is_done(is_done),
        .self_test_done(self_test_done),
        .sensor_read_start(sensor_read_start),
        .is_sweep_start(is_sweep_start),
        .self_test_start(self_test_start),
        .power_analog_en(power_analog_en),
        .power_digital_en(power_digital_en),
        .int_out_n(int_out_n),
        .current_mode(current_mode),
        .status_ready(status_ready),
        .status_measuring(status_measuring),
        .status_alert_active(status_alert_active),
        .status_is_done(status_is_done)
    );

    // 1 MHz clock
    always #500 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check_mode(input [2:0] m, input [127:0] tag);
        begin
            if (current_mode === m) begin
                $display("PASS [%0s]: mode=%0d", tag, current_mode);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: mode=%0d expected=%0d", tag, current_mode, m);
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
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    initial begin
        // ----------------------------------------------------------------
        // T01-04: Reset state
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);
        check_mode(3'd0, "T01_reset_sleep");
        check_eq(status_ready, 1'b1, "T02_status_ready");
        check_eq(power_analog_en, 1'b0, "T03_analog_off");
        check_eq(int_out_n, 1'b1, "T04_int_high_idle");

        // ----------------------------------------------------------------
        // T05: Chip disabled ignores wake
        // ----------------------------------------------------------------
        ctrl_reg = 16'h0000;
        wake_pulse = 1'b1;
        @(posedge clk);
        wake_pulse = 1'b0;
        wait_cycles(3);
        check_mode(3'd0, "T05_disabled_no_wake");

        // ----------------------------------------------------------------
        // T06-09: NORMAL cycle no-IS
        // ----------------------------------------------------------------
        ctrl_reg = 16'h0001;  // enable only
        wake_pulse = 1'b1;
        @(posedge clk);
        wake_pulse = 1'b0;
        @(posedge clk);  // now in WARMUP
        check_mode(3'd1, "T06_warmup_is_NORMAL");

        wait_cycles(15);  // past warmup
        // should be in SENSE
        check_mode(3'd1, "T07_sense_is_NORMAL");

        sensor_read_done = 1'b1;
        @(posedge clk);
        sensor_read_done = 1'b0;
        wait_cycles(3);
        check_mode(3'd0, "T08_no_IS_back_to_sleep");
        check_eq(power_analog_en, 1'b0, "T09_analog_off_post");

        // ----------------------------------------------------------------
        // T10-12: NORMAL cycle WITH IS (CTRL[8]=1)
        // ----------------------------------------------------------------
        ctrl_reg = 16'h0101;
        wake_pulse = 1'b1;
        @(posedge clk);
        wake_pulse = 1'b0;
        wait_cycles(20);  // through warmup into SENSE
        sensor_read_done = 1'b1;
        @(posedge clk);
        sensor_read_done = 1'b0;
        wait_cycles(2);
        check_mode(3'd1, "T10_IS_sweep_NORMAL");
        is_done = 1'b1;
        @(posedge clk);
        is_done = 1'b0;
        wait_cycles(3);
        check_mode(3'd0, "T11_post_IS_sleep");
        check_eq(status_is_done, 1'b0, "T12_is_done_consumed");

        // ----------------------------------------------------------------
        // T13-15: BUG-1 fix — VALIDATION goes through WARMUP
        // ----------------------------------------------------------------
        trigger_reg = 16'h0004;  // self_test
        @(posedge clk);
        trigger_reg = 16'h0000;
        @(posedge clk);  // WARMUP now, pending_target=VALIDATION
        // During WARMUP the mode should already be VALIDATION (operator intent)
        check_mode(3'd3, "T13_warmup_is_VALIDATION");
        check_eq(power_analog_en, 1'b1, "T14_analog_on_warmup");
        wait_cycles(20);  // past warmup -> S_VALIDATION
        self_test_done = 1'b1;
        @(posedge clk);
        self_test_done = 1'b0;
        wait_cycles(2);
        check_mode(3'd0, "T15_validation_to_sleep");

        // ----------------------------------------------------------------
        // T16-19: BUG-2 fix — ALERT as level overlay
        // ----------------------------------------------------------------
        ctrl_reg = 16'h0001;
        // Trigger alert before cycle
        alert_active = 1'b1;
        @(posedge clk);
        alert_active = 1'b0;  // alert_engine pulses or holds; we test latch
        @(posedge clk);
        check_mode(3'd2, "T16_alert_overlay");
        check_eq(int_out_n, 1'b0, "T17_int_low_in_alert");

        // FSM should still cycle when wake fires (NORMAL underneath ALERT)
        wake_pulse = 1'b1;
        @(posedge clk);
        wake_pulse = 1'b0;
        wait_cycles(20);  // warmup + into sense
        sensor_read_done = 1'b1;
        @(posedge clk);
        sensor_read_done = 1'b0;
        wait_cycles(3);
        // Cycled, still alert latched, mode still ALERT
        check_mode(3'd2, "T18_cycle_under_alert");

        // ack clears alert
        ack_pulse = 1'b1;
        @(posedge clk);
        ack_pulse = 1'b0;
        wait_cycles(2);
        check_mode(3'd0, "T19_ack_clears");
        check_eq(int_out_n, 1'b1, "T19b_int_high_post_ack");

        // ----------------------------------------------------------------
        // T20-21: DEBUG priority over alert
        // ----------------------------------------------------------------
        alert_active = 1'b1;
        @(posedge clk);
        alert_active = 1'b0;
        debug_enter = 1'b1;
        @(posedge clk);
        debug_enter = 1'b0;
        wait_cycles(2);
        check_mode(3'd4, "T20_debug_over_alert");
        debug_exit = 1'b1;
        @(posedge clk);
        debug_exit = 1'b0;
        wait_cycles(2);
        // After leaving DEBUG, alert is still latched
        check_mode(3'd2, "T21_back_to_alert");
        // Clean up alert
        ack_pulse = 1'b1;
        @(posedge clk);
        ack_pulse = 1'b0;
        wait_cycles(2);

        // ----------------------------------------------------------------
        // T22-23: VALIDATION priority over alert
        // ----------------------------------------------------------------
        alert_active = 1'b1;
        @(posedge clk);
        alert_active = 1'b0;
        trigger_reg = 16'h0004;
        @(posedge clk);
        trigger_reg = 16'h0000;
        wait_cycles(2);
        // We're in WARMUP heading to VALIDATION; alert is latched.
        // VALIDATION should override ALERT in mode mapping.
        check_mode(3'd3, "T22_val_over_alert");
        wait_cycles(20);
        self_test_done = 1'b1;
        @(posedge clk);
        self_test_done = 1'b0;
        wait_cycles(2);
        // Validation finished, alert still latched
        check_mode(3'd2, "T23_alert_resumes_after_val");
        ack_pulse = 1'b1;
        @(posedge clk);
        ack_pulse = 1'b0;
        wait_cycles(2);

        // ----------------------------------------------------------------
        // T24: trig_clear_state mid-cycle forces DEEP_SLEEP
        // ----------------------------------------------------------------
        wake_pulse = 1'b1;
        @(posedge clk);
        wake_pulse = 1'b0;
        wait_cycles(5);  // mid-warmup
        trigger_reg = 16'h0008;  // clear_state
        @(posedge clk);
        trigger_reg = 16'h0000;
        wait_cycles(2);
        check_mode(3'd0, "T24_clear_forces_sleep");

        // ----------------------------------------------------------------
        // T25: trig_is_sweep latches even with CTRL[8]=0
        // ----------------------------------------------------------------
        ctrl_reg = 16'h0001;  // IS-in-normal DISABLED
        trigger_reg = 16'h0002;  // IS_sweep
        @(posedge clk);
        trigger_reg = 16'h0000;
        wait_cycles(20);  // warmup + into SENSE
        sensor_read_done = 1'b1;
        @(posedge clk);
        sensor_read_done = 1'b0;
        wait_cycles(2);
        // Even though CTRL[8]=0, we should be in IS_SWEEP because the trigger latched
        check_mode(3'd1, "T25_IS_pending_latched");
        is_done = 1'b1;
        @(posedge clk);
        is_done = 1'b0;
        wait_cycles(3);

        // ----------------------------------------------------------------
        // T26: alert_active falling alone does NOT clear latch (ack required)
        // ----------------------------------------------------------------
        alert_active = 1'b1;
        @(posedge clk);
        alert_active = 1'b0;  // alert_engine drops the level
        wait_cycles(5);
        // Latched should still be high (no ack)
        check_mode(3'd2, "T26_latch_holds_no_ack");
        ack_pulse = 1'b1;
        @(posedge clk);
        ack_pulse = 1'b0;
        wait_cycles(2);

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("");
        $display("==========================================");
        $display("Scheduler tests: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL SCHEDULER TESTS PASSED ***");
        else
            $display("*** SCHEDULER FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout reached");
        $finish;
    end

endmodule
