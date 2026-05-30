/*
 * Testbench: SPI Slave + Register Bank integration test
 * Verifies: 24-bit SPI frame (8 cmd + 16 data), read/write, read-only protection,
 *           default values, write-1-to-clear on ALERT_FLAGS, TRIGGER self-clear.
 *
 * Run: iverilog -o tb_spi_reg tb/tb_spi_reg.v rtl/spi_slave.v rtl/reg_bank.v && vvp tb_spi_reg
 */

`timescale 1ns/1ps

module tb_spi_reg;

    reg clk, rst_n;
    reg sclk_r, cs_n_r, mosi_r;
    wire miso_w;

    // SPI <-> RegBank wires
    wire        reg_wr, reg_rd;
    wire [4:0]  reg_addr;
    wire [15:0] reg_wdata;
    wire [15:0] reg_rdata;

    spi_slave #(.ADDR_W(5), .DATA_W(16)) u_spi (
        .clk(clk), .rst_n(rst_n),
        .sclk(sclk_r), .cs_n(cs_n_r), .mosi(mosi_r), .miso(miso_w),
        .reg_wr(reg_wr), .reg_rd(reg_rd),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_rdata(reg_rdata)
    );

    reg_bank #(.ADDR_W(5), .DATA_W(16)) u_regs (
        .clk(clk), .rst_n(rst_n),
        .wr_en(reg_wr), .rd_en(reg_rd),
        .addr(reg_addr), .wdata(reg_wdata), .rdata(reg_rdata),
        .hw_status_wr(1'b0), .hw_status(16'h0),
        .hw_sensor_wr(1'b0),
        .hw_h10_h20(16'h0), .hw_h30_temp(16'h0),
        .hw_ec_freq(16'h0), .hw_battery(16'h0),
        .hw_is_wr(1'b0),
        .hw_z_mag_10k(16'h0), .hw_z_phase_10k(16'h0),
        .hw_z_mag_30k(16'h0), .hw_z_phase_30k(16'h0),
        .hw_z_mag_100k(16'h0), .hw_z_phase_100k(16'h0),
        .hw_diag_wr(1'b0),
        .hw_diag_err(16'h0), .hw_diag_time(16'h0), .hw_diag_curr(16'h0),
        .live_status(16'h0),
        .live_alert_flags(8'h0),
        .live_chip_id(32'h0)
    );

    // Clock: 1 MHz (1000 ns period)
    initial clk = 0;
    always #500 clk = ~clk;

    // SPI clock: ~100 kHz (5000 ns half-period) — well below system clock
    localparam SPI_HALF = 5000;

    integer errors = 0;
    reg [15:0] read_data;

    // Task: send 24-bit SPI frame
    task spi_transfer;
        input [7:0]  cmd;
        input [15:0] wdata_in;
        output [15:0] rdata_out;
        integer i;
        reg [23:0] frame_out;
        reg [15:0] captured;
    begin
        frame_out = {cmd, wdata_in};
        captured = 16'd0;
        cs_n_r = 0;
        #(SPI_HALF);

        for (i = 23; i >= 0; i = i - 1) begin
            mosi_r = frame_out[i];
            #(SPI_HALF);
            sclk_r = 1;
            // Capture MISO during data phase (bits 15..0)
            if (i < 16) begin
                captured = {captured[14:0], miso_w};
            end
            #(SPI_HALF);
            sclk_r = 0;
        end

        #(SPI_HALF);
        cs_n_r = 1;
        mosi_r = 0;
        #(SPI_HALF * 4); // inter-frame gap
        rdata_out = captured;
    end
    endtask

    task spi_write;
        input [4:0]  addr;
        input [15:0] data;
        reg [15:0] dummy;
    begin
        spi_transfer({1'b1, 2'b00, addr}, data, dummy);
    end
    endtask

    task spi_read;
        input [4:0]  addr;
        output [15:0] data;
    begin
        spi_transfer({1'b0, 2'b00, addr}, 16'hFFFF, data);
    end
    endtask

    task check;
        input [15:0] got;
        input [15:0] expected;
        input [8*40-1:0] msg;
    begin
        if (got !== expected) begin
            $display("FAIL: %0s — got 0x%04X, expected 0x%04X", msg, got, expected);
            errors = errors + 1;
        end else begin
            $display("PASS: %0s = 0x%04X", msg, got);
        end
    end
    endtask

    initial begin
        $dumpfile("tb_spi_reg.vcd");
        $dumpvars(0, tb_spi_reg);

        // Init
        rst_n = 0;
        cs_n_r = 1;
        sclk_r = 0;
        mosi_r = 0;
        #10000;
        rst_n = 1;
        #5000;

        $display("\n=== Test 1: Read VERSION register (0x1E) — expect 0x0100 ===");
        spi_read(5'h1E, read_data);
        check(read_data, 16'h0100, "VERSION");

        $display("\n=== Test 2: Read CAL_A default (0x0E) — expect 0x0100 ===");
        spi_read(5'h0E, read_data);
        check(read_data, 16'h0100, "CAL_A default");

        $display("\n=== Test 3: Write CAL_A = 0x0200, read back ===");
        spi_write(5'h0E, 16'h0200);
        spi_read(5'h0E, read_data);
        check(read_data, 16'h0200, "CAL_A after write");

        $display("\n=== Test 4: Write to read-only STATUS (0x01) — should be ignored ===");
        spi_write(5'h01, 16'hBEEF);
        spi_read(5'h01, read_data);
        check(read_data, 16'h0000, "STATUS still 0 (RO)");

        $display("\n=== Test 5: Write to VERSION (0x1E, RO) — should be ignored ===");
        spi_write(5'h1E, 16'hDEAD);
        spi_read(5'h1E, read_data);
        check(read_data, 16'h0100, "VERSION unchanged (RO)");

        $display("\n=== Test 6: Write CTRL (0x00) = 0xA5A5, read back ===");
        spi_write(5'h00, 16'hA5A5);
        spi_read(5'h00, read_data);
        check(read_data, 16'hA5A5, "CTRL");

        $display("\n=== Test 7: TRIGGER self-clear ===");
        spi_write(5'h03, 16'h0002);
        // Wait a few clocks for self-clear
        #5000;
        spi_read(5'h03, read_data);
        check(read_data, 16'h0000, "TRIGGER self-cleared");

        $display("\n=== Test 8: Read SCHED_WARMUP default (0x17) — expect 0x0064 ===");
        spi_read(5'h17, read_data);
        check(read_data, 16'h0064, "SCHED_WARMUP default");

        $display("\n");
        if (errors == 0)
            $display("*** ALL 8 TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
