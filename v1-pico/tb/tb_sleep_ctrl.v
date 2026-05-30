/*
 * Testbench: sleep_ctrl.v -- per-subsystem enable fan-out
 */

`timescale 1ns/1ps

module tb_sleep_ctrl;

    reg         power_analog_en = 0;
    reg         power_digital_en = 0;
    reg  [2:0]  current_mode = 3'd0;

    wire en_bandgap, en_adc, en_dds_dac, en_tia, en_mixer, en_clock_main;

    sleep_ctrl dut (
        .power_analog_en(power_analog_en),
        .power_digital_en(power_digital_en),
        .current_mode(current_mode),
        .en_bandgap(en_bandgap),
        .en_adc(en_adc),
        .en_dds_dac(en_dds_dac),
        .en_tia(en_tia),
        .en_mixer(en_mixer),
        .en_clock_main(en_clock_main)
    );

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

    initial begin
        // T01-06: both off
        power_analog_en = 0;
        power_digital_en = 0;
        #10;
        check_eq(en_bandgap,    0, "T01_bg_off");
        check_eq(en_adc,        0, "T02_adc_off");
        check_eq(en_dds_dac,    0, "T03_dds_off");
        check_eq(en_tia,        0, "T04_tia_off");
        check_eq(en_mixer,      0, "T05_mixer_off");
        check_eq(en_clock_main, 0, "T06_clk_off");

        // T07-12: both on
        power_analog_en = 1;
        power_digital_en = 1;
        #10;
        check_eq(en_bandgap,    1, "T07_bg_on");
        check_eq(en_adc,        1, "T08_adc_on");
        check_eq(en_dds_dac,    1, "T09_dds_on");
        check_eq(en_tia,        1, "T10_tia_on");
        check_eq(en_mixer,      1, "T11_mixer_on");
        check_eq(en_clock_main, 1, "T12_clk_on");

        // T13-14: digital only (analog off, digital on)
        power_analog_en = 0;
        power_digital_en = 1;
        #10;
        check_eq(en_bandgap,    0, "T13_bg_off_dig_only");
        check_eq(en_clock_main, 1, "T14_clk_on_dig_only");

        $display("");
        $display("==========================================");
        $display("sleep_ctrl tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL SLEEP_CTRL TESTS PASSED ***");
        else
            $display("*** SLEEP_CTRL FAILED ***");
        $display("==========================================");
        $finish;
    end

endmodule
