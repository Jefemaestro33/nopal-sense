/*
 * Testbench: alert_engine.v
 *
 * Covers:
 *  T01-02 reset → flags=0, alert_active=0
 *  T03    disabled engine ignores violating conditions
 *  T04-07 each of the 4 active comparators fires in isolation
 *  T08    multiple violations latch simultaneously
 *  T09    flag persists after the condition resolves
 *  T10    alert_clear clears a specific bit
 *  T11    persistent violation re-asserts after clear
 *  T12    reserved bits 4-7 always 0
 *  T13    clear-and-fire in same cycle resolves to cleared
 */

`timescale 1ns/1ps

module tb_alert_engine;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        enable = 1'b0;

    reg [15:0] h10_h20 = 16'h0000;
    reg [15:0] h30_temp = 16'h0000;
    reg [15:0] battery = 16'h0000;

    reg [15:0] th_vpd  = 16'h1800;  // 24
    reg [15:0] th_hum  = 16'h3700;  // 55
    reg [15:0] th_temp = 16'h0500;  // 5
    reg [15:0] th_bat  = 16'h5400;  // 84

    reg [7:0]  alert_clear = 8'h00;

    wire [7:0] alert_flags;
    wire       alert_active;

    alert_engine dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .h10_h20(h10_h20), .h30_temp(h30_temp), .battery(battery),
        .th_vpd(th_vpd), .th_hum(th_hum),
        .th_temp(th_temp), .th_bat(th_bat),
        .alert_clear(alert_clear),
        .alert_flags(alert_flags),
        .alert_active(alert_active)
    );

    always #500 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check_eq(input [31:0] val, input [31:0] expected, input [127:0] tag);
        begin
            if (val === expected) begin
                $display("PASS [%0s]: 0x%0h", tag, val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got 0x%0h expected 0x%0h",
                         tag, val, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycles(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) @(posedge clk);
    endtask

    initial begin
        // ----------------------------------------------------------------
        // T01-02: Reset
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T01_reset_flags");
        check_eq({31'd0, alert_active}, 32'd0, "T02_reset_active");

        // Safe sensor defaults — values above each below-threshold
        // and below each above-threshold so no comparator fires until
        // we deliberately violate one. This mirrors what the scheduler
        // will guarantee in real silicon (enable=0 until is_fsm has
        // written at least one valid sensor read).
        h10_h20  = {8'd30, 8'd50};    // H20=30 (< 55), H10=50 (> 24)
        h30_temp = {8'd20, 8'd0};     // TEMP=20 (> 5)
        battery  = 16'd100;            // BAT=100 (> 84)

        // ----------------------------------------------------------------
        // T03: Disabled engine — violating values yield no alerts
        // ----------------------------------------------------------------
        enable = 0;
        h10_h20 = {8'd30, 8'd16};     // H10 = 16 < TH_VPD = 24 (would fire)
        wait_cycles(3);
        check_eq({24'd0, alert_flags}, 32'd0, "T03_disabled");

        // Restore safe values before enabling
        h10_h20 = {8'd30, 8'd50};
        wait_cycles(2);

        // ----------------------------------------------------------------
        // T04: bit 0 fires — H10 < TH_VPD
        // ----------------------------------------------------------------
        enable = 1;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T04_safe_before");

        h10_h20 = {8'd30, 8'd16};     // H10 = 16 < 24
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h01, "T04b_bit0_dry");

        // Clear bit 0, raise H10 so condition resolves
        alert_clear = 8'h01;
        h10_h20 = {8'd30, 8'd50};
        wait_cycles(2);
        alert_clear = 8'h00;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T04c_bit0_cleared");

        // ----------------------------------------------------------------
        // T05: bit 1 fires — H20 > TH_HUM
        // ----------------------------------------------------------------
        h10_h20 = {8'd80, 8'd50};    // H20=80 > 55, H10=50 (safe)
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h02, "T05_bit1_sat");
        alert_clear = 8'h02;
        h10_h20 = {8'd30, 8'd50};
        wait_cycles(2);
        alert_clear = 8'h00;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T05b_bit1_cleared");

        // ----------------------------------------------------------------
        // T06: bit 2 fires — TEMP < TH_TEMP
        // ----------------------------------------------------------------
        h30_temp = {8'd2, 8'd0};      // TEMP=2 < 5 (freeze)
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h04, "T06_bit2_freeze");
        alert_clear = 8'h04;
        h30_temp = {8'd20, 8'd0};
        wait_cycles(2);
        alert_clear = 8'h00;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T06b_bit2_cleared");

        // ----------------------------------------------------------------
        // T07: bit 3 fires — BAT < TH_BAT
        // ----------------------------------------------------------------
        battery = 16'd80;             // BAT=80 < 84 (low)
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h08, "T07_bit3_low_bat");
        alert_clear = 8'h08;
        battery = 16'd100;
        wait_cycles(2);
        alert_clear = 8'h00;
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'd0, "T07b_bit3_cleared");

        // ----------------------------------------------------------------
        // T08: Multiple violations at once
        // ----------------------------------------------------------------
        h10_h20  = {8'd80, 8'd16};    // H20=80>55 (bit1), H10=16<24 (bit0)
        h30_temp = {8'd2, 8'd0};      // TEMP=2<5 (bit2)
        battery  = 16'd80;             // BAT=80<84 (bit3)
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h0F, "T08_all_4_fire");
        check_eq({31'd0, alert_active}, 32'd1, "T08b_active_high");

        // ----------------------------------------------------------------
        // T09: Resolve conditions, flags STAY set (latch)
        // ----------------------------------------------------------------
        h10_h20  = {8'd30, 8'd50};    // all values safe
        h30_temp = {8'd20, 8'd0};
        battery  = 16'd100;
        wait_cycles(3);
        check_eq({24'd0, alert_flags}, 32'h0F, "T09_flags_persist");

        // ----------------------------------------------------------------
        // T10: alert_clear clears one bit while others stay
        // ----------------------------------------------------------------
        alert_clear = 8'h02;          // clear bit 1 only
        wait_cycles(1);
        alert_clear = 8'h00;
        wait_cycles(1);
        check_eq({24'd0, alert_flags}, 32'h0D, "T10_clear_one_bit");

        // ----------------------------------------------------------------
        // T11: Re-violate bit 1 → re-asserts
        // ----------------------------------------------------------------
        h10_h20 = {8'd80, 8'd50};    // H20 back > TH_HUM
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h0F, "T11_re_assert");

        // ----------------------------------------------------------------
        // T12: Clear all and check reserved bits stay 0
        // ----------------------------------------------------------------
        h10_h20  = {8'd30, 8'd50};
        h30_temp = {8'd20, 8'd0};
        battery  = 16'd100;
        alert_clear = 8'hFF;
        wait_cycles(2);
        alert_clear = 8'h00;
        wait_cycles(1);
        check_eq({24'd0, alert_flags}, 32'd0, "T12_cleared_all");
        check_eq({24'd0, alert_flags & 8'hF0}, 32'd0, "T12b_reserved_zero");

        // ----------------------------------------------------------------
        // T13: Clear-and-fire in same cycle — clear wins, fire re-asserts
        //      next cycle
        // ----------------------------------------------------------------
        h10_h20 = {8'd30, 8'd16};    // bit 0 dry condition
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h01, "T13_bit0_fired");

        alert_clear = 8'h01;          // clear bit 0 while condition active
        wait_cycles(1);
        alert_clear = 8'h00;
        // In the cleared cycle, flag transiently is 0;
        // next cycle the condition (still active) re-sets it.
        wait_cycles(2);
        check_eq({24'd0, alert_flags}, 32'h01, "T13b_re_set_immediately");

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("");
        $display("==========================================");
        $display("alert_engine tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL ALERT_ENGINE TESTS PASSED ***");
        else
            $display("*** ALERT_ENGINE FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL: timeout reached");
        $finish;
    end

endmodule
