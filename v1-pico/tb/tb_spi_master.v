/*
 * Testbench: spi_master.v
 *
 * Connects MOSI/SCK/CS_N to a mock SPI slave that captures the
 * incoming byte and drives a known pattern on MISO. Verifies one
 * full byte transfer end-to-end.
 */

`timescale 1ns/1ps

module tb_spi_master;

    reg         clk = 0;
    reg         rst_n = 0;
    reg         start = 0;
    reg  [7:0]  wdata = 0;
    wire [7:0]  rdata;
    wire        done;
    wire        sck;
    wire        mosi;
    reg         miso = 0;
    wire        cs_n;

    spi_master #(.CLK_DIV(2)) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .wdata(wdata),
        .rdata(rdata), .done(done),
        .sck(sck), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    always #500 clk = ~clk;

    // Mock slave: capture MOSI on rising SCK, drive MISO from a
    // pre-loaded shift register, set MISO on falling SCK.
    reg [7:0] slave_rx = 0;
    reg [7:0] slave_tx = 8'h5A;   // known pattern returned to master
    reg [2:0] slave_bit = 0;
    reg       prev_sck = 0;

    always @(posedge clk) begin
        if (!cs_n) begin
            if (sck && !prev_sck) begin           // rising edge
                slave_rx <= {slave_rx[6:0], mosi};
            end
            if (!sck && prev_sck) begin           // falling edge: prep next MISO
                slave_tx <= {slave_tx[6:0], 1'b0};
            end
        end else begin
            slave_bit <= 0;
            slave_tx  <= 8'h5A;
        end
        prev_sck <= sck;
    end

    always @(*) begin
        miso = slave_tx[7];
    end

    integer pass_count = 0;
    integer fail_count = 0;

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

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_eq({24'd0, cs_n}, 32'd1, "T01_cs_idle_high");
        check_eq({31'd0, sck}, 32'd0, "T02_sck_idle_low");

        // Send 0xA3, expect master to receive 0x5A from slave
        wdata = 8'hA3;
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for done
        begin : wait_done
            integer t;
            t = 0;
            while (!done && t < 200) begin
                @(posedge clk);
                t = t + 1;
            end
            if (t >= 200) begin
                $display("FAIL [T03_timeout]");
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T03_done_in_time]: %0d cycles", t);
                pass_count = pass_count + 1;
            end
        end

        check_eq({24'd0, rdata},    32'h5A, "T04_rdata_from_slave");
        check_eq({24'd0, slave_rx}, 32'hA3, "T05_slave_got_wdata");

        @(posedge clk);
        check_eq({24'd0, cs_n}, 32'd1, "T06_cs_back_high");

        $display("");
        $display("==========================================");
        $display("spi_master tests: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL SPI_MASTER TESTS PASSED ***");
        else
            $display("*** SPI_MASTER FAILED ***");
        $display("==========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
