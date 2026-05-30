/*
 * Testbench: calibration.v
 *   y = a*x + b - alpha*(T - Tref)
 *
 * All values in Q8.8 except alpha which is Q4.12. Tests pick known
 * coefficients so y can be computed by hand to within 1-2 LSB.
 */

`timescale 1ns/1ps

module tb_calibration;

    reg                 clk = 1'b0;
    reg                 rst_n = 1'b0;
    reg                 start = 1'b0;
    reg  signed [15:0]  x = 0;
    reg  signed [15:0]  t = 0;
    reg  signed [15:0]  cal_a = 0;
    reg  signed [15:0]  cal_b = 0;
    reg  signed [15:0]  cal_alpha = 0;
    reg  signed [15:0]  cal_tref = 0;
    wire signed [15:0]  y;
    wire                done;

    calibration dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .x(x), .t(t),
        .cal_a(cal_a), .cal_b(cal_b),
        .cal_alpha(cal_alpha), .cal_tref(cal_tref),
        .y(y), .done(done)
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
            v = val;  // sign extend automatically since val is signed
            if (iabs(v - expected) <= tol) begin
                $display("PASS [%0s]: %0d (exp %0d)", tag, v, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got %0d expected %0d", tag, v, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task run_op(
        input signed [15:0] _x,
        input signed [15:0] _t,
        input signed [15:0] _a,
        input signed [15:0] _b,
        input signed [15:0] _alpha,
        input signed [15:0] _tref
    );
        begin
            x = _x; t = _t;
            cal_a = _a; cal_b = _b;
            cal_alpha = _alpha; cal_tref = _tref;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // T01: identity y = 1.0 * 10 + 0 - 0 * 0 = 10
        // x=10 in Q8.8 = 2560; a=1.0 = 256; b=0; alpha=0; tref=20=5120; t=20=5120
        run_op(16'sd2560, 16'sd5120, 16'sd256, 16'sd0, 16'sd0, 16'sd5120);
        check_close(y, 2560, 2, "T01_identity");

        // T02: y = 2.0 * 10 + 5 - 0 = 25
        // a=2.0=512, b=5=1280
        run_op(16'sd2560, 16'sd5120, 16'sd512, 16'sd1280, 16'sd0, 16'sd5120);
        check_close(y, 6400, 2, "T02_2x_plus_5");

        // T03: y = 1.0 * 10 + 0 - 0.01 * (30 - 20) = 10 - 0.1 = 9.9
        // alpha = 0.01 in Q4.12 = round(0.01 * 4096) = 41
        // t = 30 in Q8.8 = 7680
        // expected y_q88 = round(9.9 * 256) = 2534
        run_op(16'sd2560, 16'sd7680, 16'sd256, 16'sd0, 16'sd41, 16'sd5120);
        check_close(y, 2534, 4, "T03_temp_correction");

        // T04: negative x
        // y = 1.0 * -10 + 0 - 0 = -10
        run_op(-16'sd2560, 16'sd5120, 16'sd256, 16'sd0, 16'sd0, 16'sd5120);
        check_close(y, -2560, 2, "T04_negative_x");

        // T05: gain 0.5
        // y = 0.5 * 10 = 5
        // a = 0.5 = 128
        run_op(16'sd2560, 16'sd5120, 16'sd128, 16'sd0, 16'sd0, 16'sd5120);
        check_close(y, 1280, 2, "T05_gain_half");

        $display("");
        $display("==========================================");
        $display("calibration tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL CALIBRATION TESTS PASSED ***");
        else
            $display("*** CALIBRATION FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
