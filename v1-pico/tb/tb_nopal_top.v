/*
 * Testbench: nopal_sense_top -- full IS-sweep top-level verification
 *
 * Drives nopal_sense_top directly (where the adc_* interface is exposed)
 * with a behavioral ADC model, so the impedance-spectroscopy datapath
 * SPI -> reg_bank -> scheduler -> is_fsm -> CORDIC -> Z registers can be
 * exercised end-to-end. The chip_core pad wrapper ties adc_valid=0, so
 * this coverage is impossible through tb_chip_core (by design).
 *
 * Test plan:
 *   A. Responsive ADC: trigger an IS sweep, confirm the three Z_MAG /
 *      Z_PHASE register pairs are populated with a real CORDIC result.
 *      (Characterizes existing RTL that was previously unreachable.)
 *   B. Silent ADC (fault): trigger a sweep, confirm is_fsm times out,
 *      raises STATUS.error, and returns to sleep instead of hanging
 *      (SPEC REQ-IS-012). Drives the is_fsm timeout production code.
 */

`timescale 1ns/1ps
`default_nettype none

module tb_nopal_top;

    reg clk = 0;
    reg rst_n = 0;

    // SPI slave (host)
    reg  spi_sclk = 0;
    reg  spi_cs_n = 1;
    reg  spi_mosi = 0;
    wire spi_miso;

    // ADC behavioral model wiring
    wire        adc_start;
    wire [2:0]  adc_mux_sel;
    wire        adc_valid;
    wire signed [13:0] adc_data;
    reg         adc_silent = 0;
    reg [2:0]   adc_silent_from = 3'd7;   // 7 = no per-channel silence

    // Unused/idle top ports
    wire        int_out_n, clk_out;
    wire [6:0]  gpio_sw;
    wire        owire_out, owire_oe;
    wire        i2c_sda_out, i2c_sda_oe, i2c_scl_out, i2c_scl_oe;
    wire        spi_m_sck, spi_m_mosi, spi_m_cs_n;
    wire [9:0]  dac_code;
    wire        dac_enable, bandgap_en, tia_en, mixer_en, adc_en;
    wire [31:0] chip_id_out;

    nopal_sense_top dut (
        .clk(clk), .clk_32k(clk), .rst_n(rst_n),
        .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .int_out_n(int_out_n),
        .gpio_sw(gpio_sw),
        .clk_out(clk_out),
        .owire_in(1'b1), .owire_out(owire_out), .owire_oe(owire_oe),
        .i2c_sda_in(1'b1), .i2c_sda_out(i2c_sda_out), .i2c_sda_oe(i2c_sda_oe),
        .i2c_scl_out(i2c_scl_out), .i2c_scl_oe(i2c_scl_oe),
        .spi_m_sck(spi_m_sck), .spi_m_mosi(spi_m_mosi),
        .spi_m_miso(1'b0), .spi_m_cs_n(spi_m_cs_n),
        .pulse_in(1'b0), .tamper_in(1'b0),
        .dac_code(dac_code), .dac_enable(dac_enable),
        .bandgap_en(bandgap_en), .tia_en(tia_en), .mixer_en(mixer_en),
        .adc_en(adc_en), .adc_mux_sel(adc_mux_sel), .adc_start(adc_start),
        .adc_valid(adc_valid), .adc_data(adc_data),
        .chip_id_out(chip_id_out)
    );

    adc_behavioral u_adc (
        .clk(clk), .rst_n(rst_n),
        .adc_start(adc_start), .adc_mux_sel(adc_mux_sel),
        .silent(adc_silent), .silent_from(adc_silent_from),
        .adc_valid(adc_valid), .adc_data(adc_data)
    );

    // 1 MHz sim clock
    always #500 clk = ~clk;

    integer pass_count = 0, fail_count = 0;

    task check_true(input cond, input [255:0] tag);
        begin
            if (cond) begin
                $display("PASS [%0s]", tag);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]", tag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // --- SPI driver on dedicated host ports (mode 0, 8b cmd + 16b data) ---
    task spi_read_reg(input [4:0] addr, output [15:0] rdata);
        integer i; reg [7:0] cmd; reg [15:0] data;
        begin
            cmd = {3'b000, addr};   // bit7=0 read
            data = 16'd0;
            spi_cs_n = 1'b0;
            repeat (2) @(posedge clk);
            for (i = 7; i >= 0; i = i - 1) begin
                spi_sclk = 1'b0; spi_mosi = cmd[i];
                repeat (4) @(posedge clk);
                spi_sclk = 1'b1;
                repeat (4) @(posedge clk);
            end
            for (i = 15; i >= 0; i = i - 1) begin
                spi_sclk = 1'b0;
                repeat (4) @(posedge clk);
                spi_sclk = 1'b1;
                repeat (2) @(posedge clk);
                data[i] = spi_miso;
                repeat (2) @(posedge clk);
            end
            spi_sclk = 1'b0; spi_cs_n = 1'b1;
            repeat (4) @(posedge clk);
            rdata = data;
        end
    endtask

    task spi_write_reg(input [4:0] addr, input [15:0] wdata);
        integer i; reg [7:0] cmd;
        begin
            cmd = {1'b1, 2'b00, addr};  // bit7=1 write
            spi_cs_n = 1'b0;
            repeat (2) @(posedge clk);
            for (i = 7; i >= 0; i = i - 1) begin
                spi_sclk = 1'b0; spi_mosi = cmd[i];
                repeat (4) @(posedge clk);
                spi_sclk = 1'b1;
                repeat (4) @(posedge clk);
            end
            for (i = 15; i >= 0; i = i - 1) begin
                spi_sclk = 1'b0; spi_mosi = wdata[i];
                repeat (4) @(posedge clk);
                spi_sclk = 1'b1;
                repeat (4) @(posedge clk);
            end
            spi_sclk = 1'b0; spi_cs_n = 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    task do_reset;
        begin
            spi_cs_n = 1'b1; spi_sclk = 1'b0; spi_mosi = 1'b0;
            rst_n = 1'b0;
            repeat (10) @(posedge clk);
            rst_n = 1'b1;
            repeat (5) @(posedge clk);
        end
    endtask

    // Trigger n NORMAL sensor-read cycles. The moving average (N=4)
    // needs the window filled before the registers reach steady state.
    task do_sensor_reads(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                spi_write_reg(5'h03, 16'h0001);  // TRIGGER read_sensors
                repeat (400) @(posedge clk);
            end
        end
    endtask

    reg [15:0] mag10, mag30, mag100, ph10, st;
    reg [15:0] h1020, h30t, batt, alf;

    initial begin
        // ============================================================
        // Test A: responsive ADC -> full IS sweep populates Z registers
        //   ADC model returns I=4000, Q=3000 -> |Z| = K*5000 ~= 8234,
        //   phase = atan2(3000,4000) ~= 0.6435 rad -> Q4.12 ~= 2635.
        // ============================================================
        adc_silent = 1'b0;
        do_reset;

        spi_write_reg(5'h17, 16'h0000);  // SCHED_WARMUP = 0 -> instant warmup
        spi_write_reg(5'h00, 16'h0001);  // CTRL: chip_enable
        spi_write_reg(5'h03, 16'h0002);  // TRIGGER: IS_sweep

        repeat (5000) @(posedge clk);    // let the sweep run to completion

        spi_read_reg(5'h08, mag10);
        spi_read_reg(5'h0A, mag30);
        spi_read_reg(5'h0C, mag100);
        spi_read_reg(5'h09, ph10);

        $display("A: Z_MAG 10k=0x%0h 30k=0x%0h 100k=0x%0h  Z_PH 10k=0x%0h",
                 mag10, mag30, mag100, ph10);
        check_true((mag10 > 16'd7000) && (mag10 < 16'd9000), "A1_zmag10k_in_range");
        check_true(mag30 == mag10,  "A2_zmag30k_matches");
        check_true(mag100 == mag10, "A3_zmag100k_matches");
        check_true((ph10 > 16'd2400) && (ph10 < 16'd2800), "A4_zphase10k_in_range");

        // ============================================================
        // Test B: silent ADC -> is_fsm must time out, raise STATUS.error
        //   (bit 4), and return to sleep instead of hanging forever.
        // ============================================================
        adc_silent = 1'b1;
        do_reset;

        spi_write_reg(5'h17, 16'h0000);  // instant warmup
        spi_write_reg(5'h00, 16'h0001);  // chip_enable
        spi_write_reg(5'h03, 16'h0002);  // IS_sweep into a silent ADC

        repeat (3000) @(posedge clk);    // longer than the ADC timeout window

        spi_read_reg(5'h01, st);
        $display("B: STATUS = 0x%0h (bit4 error = %0b)", st, st[4]);
        check_true(st[4] === 1'b1, "B1_status_error_on_adc_timeout");
        // measuring (bit1) must have cleared -> not stuck mid-sweep
        check_true(st[1] === 1'b0, "B2_not_stuck_measuring");

        // ============================================================
        // Test C: NORMAL sensor read -> sensor registers populated from
        //   the ADC MUX. Channels 0..4 = H10/H20/H30/temp/battery; the
        //   ADC model returns 4000/3000/2000/1000/500, packed >>6 into
        //   the 8-bit register fields per SPEC 5.2.
        // ============================================================
        adc_silent = 1'b0;
        do_reset;
        spi_write_reg(5'h17, 16'h0000);  // instant warmup
        spi_write_reg(5'h00, 16'h0001);  // chip_enable, IS-in-normal off
        do_sensor_reads(4);              // fill the moving-average window
        spi_read_reg(5'h04, h1020);
        spi_read_reg(5'h05, h30t);
        spi_read_reg(5'h07, batt);
        $display("C: H10_H20=0x%0h H30_TEMP=0x%0h BATTERY=0x%0h", h1020, h30t, batt);
        check_true(h1020 == 16'h2E3E, "C1_h10_h20_populated");   // {H20=46,H10=62}
        check_true(h30t  == 16'h0F1F, "C2_h30_temp_populated");  // {temp=15,H30=31}
        check_true(batt  == 16'h0007, "C3_battery_populated");   // {0,batt=7}

        // ============================================================
        // Test D: real sensor data drives alerts correctly.
        //   D1: a read with alerts disabled latches NO alerts (the
        //       CTRL[9] gate holds even though battery is below thresh).
        //   D2: with valid data and alerts enabled, only the low-battery
        //       comparator fires (batt=7 < TH_BAT=0x54); the in-range
        //       humidity/temp comparators stay silent -> ALERT_FLAGS=0x08.
        // ============================================================
        adc_silent = 1'b0;
        do_reset;
        spi_write_reg(5'h17, 16'h0000);  // instant warmup
        spi_write_reg(5'h00, 16'h0001);  // chip_enable, alerts OFF
        do_sensor_reads(4);              // fill window with alerts disabled
        spi_read_reg(5'h02, alf);
        check_true(alf == 16'h0000, "D1_no_alert_when_disabled");

        spi_write_reg(5'h00, 16'h0201);  // chip_enable + alerts_enabled
        do_sensor_reads(2);              // active cycles; window already full
        spi_read_reg(5'h02, alf);
        $display("D: ALERT_FLAGS=0x%0h", alf);
        check_true(alf == 16'h0008, "D2_lowbatt_alert_fires");

        // ============================================================
        // Test E: a PARTIAL sensor read (ADC faults at ch2 mid-sweep)
        //   must NOT commit an inconsistent snapshot. Registers stay at
        //   their last-good value (here reset 0) and STATUS.error fires.
        //   Pre-fix the controller committed {ch0,ch1, stale ch2..4}.
        // ============================================================
        adc_silent      = 1'b0;
        adc_silent_from = 3'd2;          // ch0,1 respond; ch2..4 stuck
        do_reset;
        spi_write_reg(5'h17, 16'h0000);
        spi_write_reg(5'h00, 16'h0001);
        spi_write_reg(5'h03, 16'h0001);  // sensor read -> faults at ch2
        repeat (1000) @(posedge clk);
        spi_read_reg(5'h04, h1020);
        spi_read_reg(5'h01, st);
        $display("E: H10_H20=0x%0h STATUS=0x%0h", h1020, st);
        check_true(h1020 == 16'h0000, "E1_partial_timeout_no_commit");
        check_true(st[4] === 1'b1,    "E2_status_error_on_sensor_timeout");
        adc_silent_from = 3'd7;          // restore

        // ============================================================
        // Test F: calibration MAC in the sensor path. With CAL_A=2.0
        //   (Q8.8 0x0200, b=0, alpha=0) each reading is doubled before
        //   storage: raw 62/46/31/15/7 -> 124/92/62/30/14.
        // ============================================================
        adc_silent      = 1'b0;
        adc_silent_from = 3'd7;
        do_reset;
        spi_write_reg(5'h17, 16'h0000);  // instant warmup
        spi_write_reg(5'h0E, 16'h0200);  // CAL_A = 2.0
        spi_write_reg(5'h00, 16'h0001);  // chip_enable
        do_sensor_reads(4);
        spi_read_reg(5'h04, h1020);
        spi_read_reg(5'h05, h30t);
        spi_read_reg(5'h07, batt);
        $display("F: H10_H20=0x%0h H30_TEMP=0x%0h BATTERY=0x%0h", h1020, h30t, batt);
        check_true(h1020 == 16'h5C7C, "F1_calibration_gain_h10h20");  // {92,124}
        check_true(h30t  == 16'h1E3E, "F2_calibration_gain_h30temp"); // {30,62}
        check_true(batt  == 16'h000E, "F3_calibration_gain_battery"); // {0,14}

        // ============================================================
        // Test G: CAL_B offset tap (Test F only exercised CAL_A; this
        //   confirms the reg_bank->controller wiring for B). CAL_B=10.0
        //   with default a=1 -> reading+10: 62/46 -> 72/56.
        // ============================================================
        adc_silent = 1'b0; adc_silent_from = 3'd7;
        do_reset;
        spi_write_reg(5'h17, 16'h0000);
        spi_write_reg(5'h0F, 16'h0A00);  // CAL_B = 10.0
        spi_write_reg(5'h00, 16'h0001);
        do_sensor_reads(4);
        spi_read_reg(5'h04, h1020);
        $display("G: H10_H20=0x%0h", h1020);
        check_true(h1020 == 16'h3848, "G1_calibration_offset_b");  // {56,72}

        // ============================================================
        // Test H: calibration saturation. CAL_A=4.0 drives h10/h20
        //   (62*4=248, 46*4=184) past the Q8.8 field max -> must
        //   SATURATE to 127 (0x7F), not wrap to 0.
        // ============================================================
        do_reset;
        spi_write_reg(5'h17, 16'h0000);
        spi_write_reg(5'h0E, 16'h0400);  // CAL_A = 4.0
        spi_write_reg(5'h00, 16'h0001);
        do_sensor_reads(4);
        spi_read_reg(5'h04, h1020);
        $display("H: H10_H20=0x%0h", h1020);
        check_true(h1020 == 16'h7F7F, "H1_calibration_saturates");  // {127,127}

        // ============================================================
        // Test I: moving average (N=4) in the sensor pipeline. With
        //   identity calibration the first read averages h10=62 with 3
        //   zero-initialized slots (warm-up): 62/4 = 15. After the window
        //   fills (4 reads) the register reaches the steady value 62.
        // ============================================================
        adc_silent = 1'b0; adc_silent_from = 3'd7;
        do_reset;
        spi_write_reg(5'h17, 16'h0000);  // instant warmup
        spi_write_reg(5'h00, 16'h0001);  // chip_enable, identity cal
        do_sensor_reads(1);
        spi_read_reg(5'h04, h1020);
        $display("I: 1-read H10=0x%0h", h1020[7:0]);
        check_true(h1020[7:0] == 8'd15, "I1_mavg_warmup");   // 62/4
        do_sensor_reads(3);              // window now full (4 total)
        spi_read_reg(5'h04, h1020);
        $display("I: 4-read H10=0x%0h", h1020[7:0]);
        check_true(h1020[7:0] == 8'd62, "I2_mavg_steady");

        $display("");
        $display("==========================================");
        $display("nopal_top tests: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL NOPAL_TOP TESTS PASSED ***");
        else
            $display("*** NOPAL_TOP FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #40_000_000;
        $display("FAIL: global timeout (is_fsm likely hung -- no ADC timeout)");
        $finish;
    end

endmodule

`default_nettype wire
