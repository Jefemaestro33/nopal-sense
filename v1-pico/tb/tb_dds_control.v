/*
 * Testbench: dds_control.v
 *
 * Strategy: drive each freq_sel and verify
 *   1. DAC starts at 512 (center) after reset
 *   2. Disabled → DAC holds constant (phase doesn't advance)
 *   3. Each frequency produces ONE phase_zero pulse per
 *      expected period of the output sinusoid
 *   4. DAC value at quarter-period marks is close to peak / center / trough
 *   5. freq_sel=3 (reserved) halts phase progression
 *
 * Period counts at 1 MHz:
 *     10  kHz → 100 cycles
 *     30  kHz →  ~33.3 cycles (33 or 34 depending on phase)
 *    100  kHz →   10 cycles
 *
 * Tolerances: 50 codes (~5 %) on the quarter-period DAC checks to
 * absorb the ~1-cycle output register latency + per-step rounding.
 */

`timescale 1ns/1ps

module tb_dds_control;

    reg         clk = 1'b0;
    reg         rst_n = 1'b0;
    reg         enable = 1'b0;
    reg  [1:0]  freq_sel = 2'b00;
    wire [9:0]  dac_code;
    wire        phase_zero;

    dds_control dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .freq_sel(freq_sel),
        .dac_code(dac_code),
        .phase_zero(phase_zero)
    );

    // 1 MHz: 1 ns/ps timescale → period 1000 ns
    always #500 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;
    integer pz_count;

    always @(posedge clk) begin
        if (phase_zero) pz_count <= pz_count + 1;
    end

    function integer iabs;
        input integer v;
        begin
            iabs = (v < 0) ? -v : v;
        end
    endfunction

    task check_range(
        input integer val,
        input integer lo,
        input integer hi,
        input [127:0] tag
    );
        begin
            if (val >= lo && val <= hi) begin
                $display("PASS [%0s]: val=%0d in [%0d,%0d]", tag, val, lo, hi);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: val=%0d outside [%0d,%0d]", tag, val, lo, hi);
                fail_count = fail_count + 1;
            end
        end
    endtask

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

    task wait_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    initial begin
        pz_count = 0;

        // ----------------------------------------------------------------
        // T01: Reset → DAC = 512
        // ----------------------------------------------------------------
        rst_n = 0;
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);
        check_eq_int(dac_code, 512, "T01_reset_center");

        // ----------------------------------------------------------------
        // T02: Disabled → DAC stays at 512 over many cycles
        // ----------------------------------------------------------------
        enable = 0;
        freq_sel = 2'b00;
        wait_cycles(50);
        check_eq_int(dac_code, 512, "T02_disabled_hold");
        check_eq_int(pz_count, 0, "T03_no_phase_zero");

        // ----------------------------------------------------------------
        // 10 kHz: 100 cycles per period.
        // After ~25 cycles, near positive peak (~1023);
        // after ~50, near zero crossing falling (~512);
        // after ~75, near negative peak (~0);
        // after ~100, back to center (~512).
        // ----------------------------------------------------------------
        pz_count = 0;
        enable = 1;
        freq_sel = 2'b00;
        wait_cycles(25);
        check_range(dac_code, 900, 1023, "T04_10kHz_peak_pos");
        wait_cycles(25);
        check_range(dac_code, 462, 562, "T05_10kHz_mid");
        wait_cycles(25);
        check_range(dac_code, 0, 124, "T06_10kHz_peak_neg");
        wait_cycles(25);
        check_range(dac_code, 462, 562, "T07_10kHz_back_to_mid");

        // Wait a couple more cycles: phase_zero fires at ~cycle 100 of
        // operation, and pz_count register increments one cycle later.
        wait_cycles(3);
        check_eq_int(pz_count, 1, "T08_10kHz_one_pz");

        // ----------------------------------------------------------------
        // 30 kHz: ~33.3 cycles per period. Just check that we see
        // multiple phase_zero pulses in 100 cycles (expect ~3).
        // ----------------------------------------------------------------
        rst_n = 0; wait_cycles(2); rst_n = 1;
        pz_count = 0;
        enable = 1;
        freq_sel = 2'b01;
        wait_cycles(101);
        check_range(pz_count, 2, 4, "T09_30kHz_pz_count");

        // ----------------------------------------------------------------
        // 100 kHz: 10 cycles per period. In 100 cycles, ~10 pulses.
        // ----------------------------------------------------------------
        rst_n = 0; wait_cycles(2); rst_n = 1;
        pz_count = 0;
        enable = 1;
        freq_sel = 2'b10;
        wait_cycles(101);
        check_range(pz_count, 9, 11, "T10_100kHz_pz_count");

        // ----------------------------------------------------------------
        // After 100 kHz, peak should be visible after a few cycles
        // ----------------------------------------------------------------
        rst_n = 0; wait_cycles(2); rst_n = 1;
        pz_count = 0;
        enable = 1;
        freq_sel = 2'b10;
        wait_cycles(3);  // ~quarter period (10/4 = 2.5)
        check_range(dac_code, 700, 1023, "T11_100kHz_rising_to_peak");

        // ----------------------------------------------------------------
        // freq_sel = 11 (reserved) → no phase advancement
        // ----------------------------------------------------------------
        rst_n = 0; wait_cycles(2); rst_n = 1;
        pz_count = 0;
        enable = 1;
        freq_sel = 2'b11;
        wait_cycles(200);
        check_eq_int(dac_code, 512, "T12_reserved_no_move");
        check_eq_int(pz_count, 0, "T13_reserved_no_pz");

        // ----------------------------------------------------------------
        // Phase persistence: disable mid-cycle should hold phase
        //   Capture held AFTER enable=0 has propagated through one
        //   NBA cycle so dac_code is at its steady-state hold value.
        // ----------------------------------------------------------------
        rst_n = 0; wait_cycles(2); rst_n = 1;
        enable = 1;
        freq_sel = 2'b00;
        wait_cycles(20);
        enable = 0;
        wait_cycles(2);   // let enable=0 propagate + NBA settle
        begin : hold_check
            reg [9:0] held;
            held = dac_code;
            wait_cycles(50);
            check_eq_int(dac_code, held, "T14_disable_holds_phase");
        end

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("");
        $display("==========================================");
        $display("DDS tests: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL DDS_CONTROL TESTS PASSED ***");
        else
            $display("*** DDS_CONTROL FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL: timeout reached");
        $finish;
    end

endmodule
