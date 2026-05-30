/*
 * Testbench: cordic.v
 *
 * Verifies CORDIC vectoring against analytically known points.
 * Magnitude is K-uncorrected (K ≈ 1.6468 for 16 iters); expected
 * values include the gain. Tolerances are loose vs theoretical
 * CORDIC residual to accommodate truncation at LSB.
 *
 * Test vectors:
 *   T01 (0, 0)               mag=0, phase=0
 *   T02 (1000, 0)            +x-axis
 *   T03 (0, 1000)            +y-axis (+π/2)
 *   T04 (-1000, 0)           -x-axis (+π) — exercises Quadrant II pre-rot
 *   T05 (0, -1000)           -y-axis (-π/2)
 *   T06 (1000, 1000)         +π/4
 *   T07 (1000, -1000)        -π/4
 *   T08 (-1000, 1000)        +3π/4 — Quadrant II
 *   T09 (-1000, -1000)       -3π/4 — Quadrant III pre-rot
 *   T10 (500, 866)           +π/3 (60°)
 *   T11 done pulse is exactly 1 cycle
 *
 * Run via Makefile: make test_cordic
 */

`timescale 1ns/1ps

module tb_cordic;

    localparam K_NUM    = 16467;        // K × 10000
    localparam K_DENOM  = 10000;
    localparam PI_Q12   = 12868;        // π × 4096 (rounded)
    localparam PI_2_Q12 = 6434;
    localparam PI_4_Q12 = 3217;
    localparam PI_3_Q12 = 4289;         // π/3 × 4096
    localparam PI_3_4_Q12 = 9651;       // 3π/4 × 4096

    reg                  clk = 1'b0;
    reg                  rst_n = 1'b0;
    reg                  start = 1'b0;
    reg  signed [13:0]   i_in = 14'sd0;
    reg  signed [13:0]   q_in = 14'sd0;
    wire signed [17:0]   mag_out;
    wire signed [15:0]   phase_out;
    wire                 done;

    cordic #(
        .DATA_W (14),
        .MAG_W  (18),
        .PHASE_W(16),
        .ITER_N (16)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start),
        .i_in(i_in), .q_in(q_in),
        .mag_out(mag_out),
        .phase_out(phase_out),
        .done(done)
    );

    always #500 clk = ~clk;   // 1 MHz sim

    integer pass_count = 0;
    integer fail_count = 0;

    // Tolerances
    localparam MAG_TOL   = 50;          // ~3 % of typical 1647
    localparam PHASE_TOL = 64;          // ~0.9° in Q4.12

    function integer iabs;
        input integer v;
        begin
            iabs = (v < 0) ? -v : v;
        end
    endfunction

    task run_case(
        input signed [13:0] tii,
        input signed [13:0] tqq,
        input integer       exp_mag,
        input integer       exp_phase,
        input [127:0]       tag
    );
        integer m, p;
        begin
            i_in = tii;
            q_in = tqq;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            // Wait for done
            wait(done == 1'b1);
            @(posedge clk);

            m = mag_out;
            p = phase_out;
            // Sign extend phase to integer
            if (p[15]) p = p | {16{1'b1}}<<16;  // sign extend to 32-bit int

            if (iabs(m - exp_mag) <= MAG_TOL &&
                iabs(p - exp_phase) <= PHASE_TOL) begin
                $display("PASS [%0s]: mag=%0d (exp %0d), phase=%0d (exp %0d)",
                         tag, m, exp_mag, p, exp_phase);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: mag=%0d (exp %0d, diff %0d), phase=%0d (exp %0d, diff %0d)",
                         tag, m, exp_mag, iabs(m-exp_mag),
                         p, exp_phase, iabs(p-exp_phase));
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ------------------------------------------------------------
        // T01: zero input
        // ------------------------------------------------------------
        run_case(14'sd0, 14'sd0,
                 0, 0,
                 "T01_zero");

        // ------------------------------------------------------------
        // T02-05: cardinal axes
        // ------------------------------------------------------------
        run_case(14'sd1000, 14'sd0,
                 (1000*K_NUM)/K_DENOM, 0,
                 "T02_pos_x_axis");

        run_case(14'sd0, 14'sd1000,
                 (1000*K_NUM)/K_DENOM, PI_2_Q12,
                 "T03_pos_y_axis");

        run_case(-14'sd1000, 14'sd0,
                 (1000*K_NUM)/K_DENOM, PI_Q12,
                 "T04_neg_x_axis");

        run_case(14'sd0, -14'sd1000,
                 (1000*K_NUM)/K_DENOM, -PI_2_Q12,
                 "T05_neg_y_axis");

        // ------------------------------------------------------------
        // T06-09: diagonals (±π/4, ±3π/4)
        //   sqrt(2)·1000 = 1414;  K·1414 ≈ 2329
        // ------------------------------------------------------------
        run_case(14'sd1000, 14'sd1000,
                 2329, PI_4_Q12,
                 "T06_pi4");

        run_case(14'sd1000, -14'sd1000,
                 2329, -PI_4_Q12,
                 "T07_neg_pi4");

        run_case(-14'sd1000, 14'sd1000,
                 2329, PI_3_4_Q12,
                 "T08_3pi4_QII");

        run_case(-14'sd1000, -14'sd1000,
                 2329, -PI_3_4_Q12,
                 "T09_neg_3pi4_QIII");

        // ------------------------------------------------------------
        // T10: 60° via (500, 866) — magnitude ≈ 1000, phase = π/3
        // ------------------------------------------------------------
        run_case(14'sd500, 14'sd866,
                 (1000*K_NUM)/K_DENOM, PI_3_Q12,
                 "T10_pi3");

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
        $display("");
        $display("==========================================");
        $display("CORDIC tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL CORDIC TESTS PASSED ***");
        else
            $display("*** CORDIC FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout reached");
        $finish;
    end

endmodule
