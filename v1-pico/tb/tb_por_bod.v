/*
 * Testbench: por_bod.v -- power-on reset + brown-out
 *
 * Overrides POR_HOLD_CYCLES to a small value (5) for sim speed.
 * Tests: vdd_ok deasserted, reset asserted; vdd_ok asserted, reset
 * held for N cycles then released; vdd_ok drops mid-operation,
 * reset re-asserts.
 */

`timescale 1ns/1ps

module tb_por_bod;

    reg          clk_32k = 1'b0;
    reg          vdd_ok = 1'b0;
    wire         rst_n;

    localparam HOLD = 5;

    por_bod #(.POR_HOLD_CYCLES(HOLD)) dut (
        .clk_32k(clk_32k),
        .vdd_ok(vdd_ok),
        .rst_n(rst_n)
    );

    // 32 kHz clock -> ~31.25 us; use 500 ns / 1 us for sim convenience
    always #500 clk_32k = ~clk_32k;

    integer pass_count = 0;
    integer fail_count = 0;

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
        for (i = 0; i < n; i = i + 1) @(posedge clk_32k);
    endtask

    initial begin
        vdd_ok = 0;
        wait_cycles(3);
        check_eq(rst_n, 1'b0, "T01_vdd_low_rst_low");

        // Assert vdd_ok -> rst_n stays low for HOLD cycles
        vdd_ok = 1;
        @(posedge clk_32k);
        check_eq(rst_n, 1'b0, "T02_just_after_vdd_ok");

        // After HOLD-1 more cycles, still low
        wait_cycles(HOLD - 2);
        check_eq(rst_n, 1'b0, "T03_during_hold");

        // After full HOLD cycles, rst_n should release
        wait_cycles(3);
        check_eq(rst_n, 1'b1, "T04_post_hold_released");

        // Stays released
        wait_cycles(20);
        check_eq(rst_n, 1'b1, "T05_stays_released");

        // Brown-out: vdd_ok drops -> rst_n async asserted
        vdd_ok = 0;
        #100;  // sub-cycle
        check_eq(rst_n, 1'b0, "T06_brown_out_async");

        // Stays low while vdd_ok low
        wait_cycles(5);
        check_eq(rst_n, 1'b0, "T07_vdd_low_held");

        // Recovery: vdd_ok returns, must hold again
        vdd_ok = 1;
        wait_cycles(2);
        check_eq(rst_n, 1'b0, "T08_recovery_hold");

        wait_cycles(HOLD);
        check_eq(rst_n, 1'b1, "T09_recovery_released");

        $display("");
        $display("==========================================");
        $display("por_bod tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL POR_BOD TESTS PASSED ***");
        else
            $display("*** POR_BOD FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
