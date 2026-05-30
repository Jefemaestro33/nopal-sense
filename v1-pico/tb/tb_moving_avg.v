/*
 * Testbench: moving_avg.v
 *
 * Tests the running average over windows of 4/8/16 samples. Warm-up
 * cycle (where the buffer fills from initial zero) is verified by
 * counting expected values after N samples.
 */

`timescale 1ns/1ps

module tb_moving_avg;

    reg                clk = 1'b0;
    reg                rst_n = 1'b0;
    reg                enable = 1'b0;
    reg  [1:0]         window_sel = 2'd0;
    reg                sample_valid = 1'b0;
    reg  signed [15:0] sample_in = 0;
    wire signed [15:0] avg_out;

    moving_avg dut (
        .clk(clk), .rst_n(rst_n),
        .enable(enable),
        .window_sel(window_sel),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .avg_out(avg_out)
    );

    always #500 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    function integer iabs;
        input integer v;
        iabs = (v < 0) ? -v : v;
    endfunction

    task check_close(
        input signed [15:0] val,
        input integer       expected,
        input integer       tol,
        input [127:0]       tag
    );
        integer v;
        begin
            v = val;
            if (iabs(v - expected) <= tol) begin
                $display("PASS [%0s]: %0d (exp %0d)", tag, v, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got %0d expected %0d", tag, v, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task feed(input signed [15:0] s);
        begin
            sample_in = s;
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    integer i;

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // T01: Reset state
        check_close(avg_out, 0, 0, "T01_reset");

        // T02: N=4 (window_sel=0). Feed 100 four times. Avg should be 100.
        enable = 1;
        window_sel = 2'd0;
        @(posedge clk);
        for (i = 0; i < 4; i = i + 1) feed(16'sd100);
        check_close(avg_out, 100, 1, "T02_n4_avg100");

        // T03: continue feeding 100, avg stays 100
        for (i = 0; i < 4; i = i + 1) feed(16'sd100);
        check_close(avg_out, 100, 1, "T03_n4_stays_100");

        // T04: feed 4 samples of 200 -> avg = 200 after window fills
        for (i = 0; i < 4; i = i + 1) feed(16'sd200);
        check_close(avg_out, 200, 1, "T04_n4_now_200");

        // T05: N=8 (resets the filter)
        window_sel = 2'd1;
        @(posedge clk);
        @(posedge clk);
        check_close(avg_out, 0, 0, "T05_window_reset");

        // T06: feed 8 samples of 80, avg = 80
        for (i = 0; i < 8; i = i + 1) feed(16'sd80);
        check_close(avg_out, 80, 1, "T06_n8_avg80");

        // T07: N=16
        window_sel = 2'd2;
        @(posedge clk);
        @(posedge clk);
        for (i = 0; i < 16; i = i + 1) feed(16'sd320);
        check_close(avg_out, 320, 1, "T07_n16_avg320");

        // T08: negative samples handled correctly
        window_sel = 2'd0;
        @(posedge clk);
        @(posedge clk);
        for (i = 0; i < 4; i = i + 1) feed(-16'sd500);
        check_close(avg_out, -500, 1, "T08_n4_negative");

        // T09: mixed values; sum = 0+100+200+300 = 600, avg(/4) = 150
        window_sel = 2'd0;
        @(posedge clk);
        @(posedge clk);
        feed(16'sd0);
        feed(16'sd100);
        feed(16'sd200);
        feed(16'sd300);
        check_close(avg_out, 150, 1, "T09_n4_mixed");

        $display("");
        $display("==========================================");
        $display("moving_avg tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL MOVING_AVG TESTS PASSED ***");
        else
            $display("*** MOVING_AVG FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
