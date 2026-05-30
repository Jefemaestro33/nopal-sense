/*
 * Testbench: puf.v -- 32-bit chip ID
 */

`timescale 1ns/1ps

module tb_puf;

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    wire [31:0]  chip_id;

    localparam [31:0] EXPECTED = 32'hA5A5_5A5A;  // dut default

    puf dut (.clk(clk), .rst_n(rst_n), .chip_id(chip_id));

    always #500 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check_eq(input [31:0] val, input [31:0] expected, input [127:0] tag);
        begin
            if (val === expected) begin
                $display("PASS [%0s]: 0x%08h", tag, val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got 0x%08h expected 0x%08h", tag, val, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_eq(chip_id, EXPECTED, "T01_initial_id");

        // After many cycles, chip_id stable
        repeat (50) @(posedge clk);
        check_eq(chip_id, EXPECTED, "T02_stable_after_50");

        // After re-reset, same value
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        check_eq(chip_id, EXPECTED, "T03_after_re_reset");

        $display("");
        $display("==========================================");
        $display("puf tests: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL PUF TESTS PASSED ***");
        else
            $display("*** PUF FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #100000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
