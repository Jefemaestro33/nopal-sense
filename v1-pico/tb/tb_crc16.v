/*
 * Testbench: CRC-16/CCITT
 * Verifies against known test vector: CRC("123456789") = 0x29B1
 *
 * Run: iverilog -o tb_crc16 tb/tb_crc16.v rtl/crc16.v && vvp tb_crc16
 */

`timescale 1ns/1ps

module tb_crc16;

    reg clk, rst_n;
    reg init, data_valid, data_in;
    wire [15:0] crc_out;

    crc16 u_crc (
        .clk(clk), .rst_n(rst_n),
        .init(init), .data_valid(data_valid), .data_in(data_in),
        .crc_out(crc_out)
    );

    initial clk = 0;
    always #500 clk = ~clk;

    // Feed one byte MSB-first (signals change on negedge to avoid race)
    task feed_byte;
        input [7:0] b;
        integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            @(negedge clk);
            data_valid = 1;
            data_in = b[i];
            @(negedge clk);
            data_valid = 0;
        end
    end
    endtask

    integer errors = 0;

    initial begin
        $dumpfile("tb_crc16.vcd");
        $dumpvars(0, tb_crc16);

        rst_n = 0;
        init = 0;
        data_valid = 0;
        data_in = 0;
        #5000;
        rst_n = 1;
        #2000;

        // Init CRC
        @(negedge clk);
        init = 1;
        @(negedge clk);
        init = 0;

        // Feed ASCII "123456789" = 0x31..0x39
        feed_byte(8'h31);
        feed_byte(8'h32);
        feed_byte(8'h33);
        feed_byte(8'h34);
        feed_byte(8'h35);
        feed_byte(8'h36);
        feed_byte(8'h37);
        feed_byte(8'h38);
        feed_byte(8'h39);

        #2000;

        if (crc_out == 16'h29B1) begin
            $display("PASS: CRC-16/CCITT(\"123456789\") = 0x%04X (expected 0x29B1)", crc_out);
        end else begin
            $display("FAIL: CRC-16/CCITT(\"123456789\") = 0x%04X (expected 0x29B1)", crc_out);
            errors = errors + 1;
        end

        // Test 2: re-init and feed single byte 0x00
        @(negedge clk);
        init = 1;
        @(negedge clk);
        init = 0;
        feed_byte(8'h00);
        #2000;

        // CRC-16/CCITT of single 0x00 byte with init 0xFFFF = 0xE1F0
        if (crc_out == 16'hE1F0) begin
            $display("PASS: CRC-16/CCITT(0x00) = 0x%04X (expected 0xE1F0)", crc_out);
        end else begin
            $display("FAIL: CRC-16/CCITT(0x00) = 0x%04X (expected 0xE1F0)", crc_out);
            errors = errors + 1;
        end

        $display("");
        if (errors == 0)
            $display("*** ALL CRC16 TESTS PASSED ***");
        else
            $display("*** %0d CRC16 TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
