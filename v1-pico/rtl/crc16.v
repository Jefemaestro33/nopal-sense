/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// CRC-16/CCITT: polynomial 0x1021, init 0xFFFF, MSB first
// Bit-serial interface for streaming SPI master output payloads

module crc16 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        init,       // pulse: reset CRC to 0xFFFF
    input  wire        data_valid, // pulse: process one bit
    input  wire        data_in,    // serial bit input (MSB first)

    output wire [15:0] crc_out
);

    reg [15:0] crc;

    assign crc_out = crc;

    wire feedback = crc[15] ^ data_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc <= 16'hFFFF;
        end else if (init) begin
            crc <= 16'hFFFF;
        end else if (data_valid) begin
            crc[15] <= crc[14];
            crc[14] <= crc[13];
            crc[13] <= crc[12];
            crc[12] <= crc[11] ^ feedback;
            crc[11] <= crc[10];
            crc[10] <= crc[9];
            crc[9]  <= crc[8];
            crc[8]  <= crc[7];
            crc[7]  <= crc[6];
            crc[6]  <= crc[5];
            crc[5]  <= crc[4] ^ feedback;
            crc[4]  <= crc[3];
            crc[3]  <= crc[2];
            crc[2]  <= crc[1];
            crc[1]  <= crc[0];
            crc[0]  <= feedback;
        end
    end

endmodule
