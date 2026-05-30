/*
 * Testbench: chip_core.sv -- workshop-slot top-level smoke test
 *
 * Verifies the full digital integration is wired correctly by reading
 * the VERSION register via SPI (the same path ESP32 firmware will use
 * for bring-up). Anything more elaborate requires an ADC model which
 * is deferred to Phase 1b alongside the rest of the analog interface.
 *
 * Test plan:
 *   T01-04 reset state: bidir_oe correct for SPI pads, MISO released
 *          when CS deasserted, INT_OUT high (no alert), GPIO_SW = 0
 *   T05    SPI read of VERSION (addr 0x1E) returns 0x0100
 *   T06    SPI write to CTRL (addr 0x00) then read back
 *   T07    SPI read of SCHED_WARMUP returns the default 0x0064
 */

`timescale 1ns/1ps

module tb_chip_core;

    reg          clk = 0;
    reg          rst_n = 0;

    reg          input_in_r = 0;
    wire [0:0]   input_in  = input_in_r;
    wire [0:0]   input_pu, input_pd;

    reg  [19:0]  bidir_in_r = 20'd0;
    wire [19:0]  bidir_in   = bidir_in_r;
    wire [19:0]  bidir_out, bidir_oe, bidir_cs, bidir_sl,
                 bidir_ie, bidir_pu, bidir_pd;

    wire [59:0]  analog;  // floating in digital sim

    chip_core #(.NUM_INPUT_PADS(1), .NUM_BIDIR_PADS(20), .NUM_ANALOG_PADS(60))
    dut (
        .clk(clk), .rst_n(rst_n),
        .input_in(input_in), .input_pu(input_pu), .input_pd(input_pd),
        .bidir_in(bidir_in),
        .bidir_out(bidir_out), .bidir_oe(bidir_oe),
        .bidir_cs(bidir_cs),   .bidir_sl(bidir_sl),
        .bidir_ie(bidir_ie),
        .bidir_pu(bidir_pu),   .bidir_pd(bidir_pd),
        .analog(analog)
    );

    // 1 MHz sim clock
    always #500 clk = ~clk;

    integer pass_count = 0, fail_count = 0;

    task check_eq(input [31:0] val, input [31:0] expected, input [127:0] tag);
        begin
            if (val === expected) begin
                $display("PASS [%0s]: 0x%0h", tag, val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0s]: got 0x%0h expected 0x%0h", tag, val, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // SPI driver tasks. The chip's SPI slave is on:
    //   bidir[0] MOSI (we drive into bidir_in[0])
    //   bidir[1] MISO (we read from bidir_out[1])
    //   bidir[2] SCK  (drive)
    //   bidir[3] CS_N (drive, active low)
    task spi_clk_pulse;
        begin
            bidir_in_r[2] = 1'b1;
            repeat (4) @(posedge clk);
            bidir_in_r[2] = 1'b0;
            repeat (4) @(posedge clk);
        end
    endtask

    task spi_read_reg(input [4:0] addr, output [15:0] rdata);
        integer i;
        reg [7:0] cmd;
        reg [15:0] data;
        begin
            // Command byte: bit7=R/W (0=read), bits6:5=0, bits4:0=addr
            cmd  = {3'b000, addr};
            data = 16'd0;
            bidir_in_r[3] = 1'b0;     // CS low
            repeat (2) @(posedge clk);

            // Send 8 cmd bits (MSB first)
            for (i = 7; i >= 0; i = i - 1) begin
                bidir_in_r[2] = 1'b0;     // SCK low
                bidir_in_r[0] = cmd[i];   // MOSI
                repeat (4) @(posedge clk);
                bidir_in_r[2] = 1'b1;     // SCK rising edge
                repeat (4) @(posedge clk);
            end

            // Receive 16 data bits (MSB first). MISO is on bidir_out[1].
            // The slave shifts out on SCK falling edge; we sample after rise.
            for (i = 15; i >= 0; i = i - 1) begin
                bidir_in_r[2] = 1'b0;     // SCK low (slave updates MISO)
                repeat (4) @(posedge clk);
                bidir_in_r[2] = 1'b1;     // SCK high (sample)
                repeat (2) @(posedge clk);
                data[i] = bidir_out[1];
                repeat (2) @(posedge clk);
            end

            bidir_in_r[2] = 1'b0;
            bidir_in_r[3] = 1'b1;     // CS high
            repeat (4) @(posedge clk);
            rdata = data;
        end
    endtask

    task spi_write_reg(input [4:0] addr, input [15:0] wdata);
        integer i;
        reg [7:0] cmd;
        begin
            cmd = {1'b1, 2'b00, addr};  // bit 7=write
            bidir_in_r[3] = 1'b0;
            repeat (2) @(posedge clk);

            for (i = 7; i >= 0; i = i - 1) begin
                bidir_in_r[2] = 1'b0;
                bidir_in_r[0] = cmd[i];
                repeat (4) @(posedge clk);
                bidir_in_r[2] = 1'b1;
                repeat (4) @(posedge clk);
            end
            for (i = 15; i >= 0; i = i - 1) begin
                bidir_in_r[2] = 1'b0;
                bidir_in_r[0] = wdata[i];
                repeat (4) @(posedge clk);
                bidir_in_r[2] = 1'b1;
                repeat (4) @(posedge clk);
            end

            bidir_in_r[2] = 1'b0;
            bidir_in_r[3] = 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    reg [15:0] rd_val;

    initial begin
        // SPI idle: CS high, SCK low
        bidir_in_r[3] = 1'b1;
        bidir_in_r[2] = 1'b0;
        bidir_in_r[0] = 1'b0;

        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // T01-04: reset state checks
        check_eq({30'd0, bidir_oe[0], bidir_oe[2]}, 32'd0, "T01_spi_in_pads_oe0");
        check_eq({31'd0, bidir_oe[1]},              32'd1, "T02_miso_oe1");
        check_eq({31'd0, bidir_out[4]},             32'd1, "T03_int_out_high");
        check_eq({25'd0, bidir_out[12:6]},          32'd0, "T04_gpio_sw_zero");

        // T05: SPI read VERSION (addr 0x1E)
        spi_read_reg(5'h1E, rd_val);
        check_eq({16'd0, rd_val}, 32'h0100, "T05_version_0x0100");

        // T06: SPI write+read CTRL
        spi_write_reg(5'h00, 16'hA5A5);
        spi_read_reg(5'h00, rd_val);
        check_eq({16'd0, rd_val}, 32'hA5A5, "T06_ctrl_writeback");

        // T07: SPI read SCHED_WARMUP default
        spi_read_reg(5'h17, rd_val);
        check_eq({16'd0, rd_val}, 32'h0064, "T07_sched_warmup_default");

        // ============================================================
        // P0 audit-fix coverage (2026-05-29)
        // ============================================================

        // T08: STATUS (0x01) reflects live scheduler state.
        // After reset + idle, current state = DEEP_SLEEP, status_ready=1.
        // Bit layout per SPEC §5.1: ready[0], measuring[1], alert[2],
        //                           is_done[3], error[4], err_code[15:5]
        spi_read_reg(5'h01, rd_val);
        check_eq({16'd0, rd_val & 16'h001F}, 32'h0001, "T08_status_ready_bit");

        // T09: PUF_ID_LO (0x1C) returns low half of puf.SIM_PUF_VALUE
        // Default SIM_PUF_VALUE = 32'hA5A5_5A5A -> low = 0x5A5A
        spi_read_reg(5'h1C, rd_val);
        check_eq({16'd0, rd_val}, 32'h5A5A, "T09_puf_id_lo");

        // T10: PUF_ID_HI (0x1D) returns high half = 0xA5A5
        spi_read_reg(5'h1D, rd_val);
        check_eq({16'd0, rd_val}, 32'hA5A5, "T10_puf_id_hi");

        // T11: ALERT_FLAGS (0x02) reads 0 at reset (alerts disabled)
        spi_read_reg(5'h02, rd_val);
        check_eq({16'd0, rd_val}, 32'h0000, "T11_alert_flags_reset");

        // T12: Enabling chip without CTRL[9]=alerts_enabled keeps
        //      ALERT_FLAGS at 0 even though sensors read 0 (below
        //      TEMP/BAT thresholds). This is the gate that prevents
        //      false alerts on the first NORMAL cycle.
        spi_write_reg(5'h00, 16'h0001);  // chip_enable only, alerts_disabled
        repeat (20) @(posedge clk);
        spi_read_reg(5'h02, rd_val);
        check_eq({16'd0, rd_val}, 32'h0000, "T12_no_false_alerts_when_disabled");

        // T13: Trigger scheduler into active state with alerts enabled.
        //      Sensors stay at 0 (no controller yet) so the below-
        //      threshold comparators (TEMP<5, BAT<84) fire as soon
        //      as power_digital_en goes high. Proves the live wiring
        //      reg_bank -> alert_engine -> ALERT_FLAGS read path.
        spi_write_reg(5'h00, 16'h0201);  // chip_enable + alerts_enabled
        spi_write_reg(5'h17, 16'h0001);  // sched_warmup = 1 ms (fast tb)
        spi_write_reg(5'h03, 16'h0001);  // TRIGGER read_sensors
        // Need to clear WARMUP (1 ms × 1000 cyc/ms) + SENSE + propagation
        repeat (2000) @(posedge clk);
        spi_read_reg(5'h02, rd_val);
        if ((rd_val & 16'h000F) >= 8'h08) begin
            $display("PASS [T13_alerts_fire_when_enabled]: 0x%0h", rd_val & 16'h000F);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T13_alerts_fire_when_enabled]: 0x%0h", rd_val & 16'h000F);
            fail_count = fail_count + 1;
        end

        // T14: With alerts disabled first (so conditions don't re-fire),
        //      write 1 bits to ALERT_FLAGS to clear; read back.
        spi_write_reg(5'h00, 16'h0001);  // disable alerts (clear CTRL[9])
        repeat (10) @(posedge clk);
        spi_write_reg(5'h02, 16'h00FF);  // write-1-to-clear all bits
        repeat (5) @(posedge clk);
        spi_read_reg(5'h02, rd_val);
        check_eq({16'd0, rd_val}, 32'h0000, "T14_alert_flags_cleared");
        spi_read_reg(5'h01, rd_val);
        check_eq({31'd0, rd_val[2]}, 32'h0000, "T15_status_alert_cleared");
        check_eq({31'd0, bidir_out[4]}, 32'h0001, "T16_int_high_after_clear");

        $display("");
        $display("==========================================");
        $display("chip_core tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL CHIP_CORE TESTS PASSED ***");
        else
            $display("*** CHIP_CORE FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL: global timeout");
        $finish;
    end

endmodule
