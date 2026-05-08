/*
 * Copyright (c) 2026 Darell Plascencia
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Nopal-Sense: SPI Slave Interface
// Provides register read/write access to the MCU host (ESP32).
// Mode 0 (CPOL=0, CPHA=0): data sampled on rising SCLK, shifted on falling.
//
// Protocol:
//   Byte 0: [R/W bit][7-bit address]  (bit 7: 0=read, 1=write)
//   Byte 1: Data (write) or dummy (read → data returned on MISO)
//
// Active-low chip select (CS_N). MSB first.

module spi_slave #(
    parameter ADDR_W = 5,   // 32 registers
    parameter DATA_W = 8
) (
    input  wire                 clk,        // system clock (>> SCLK)
    input  wire                 rst_n,

    // SPI pins
    input  wire                 sclk,
    input  wire                 cs_n,
    input  wire                 mosi,
    output wire                 miso,

    // Register interface (directly to reg_bank)
    output reg                  reg_wr,           // pulse: write to register
    output reg                  reg_rd,           // pulse: read from register
    output reg  [ADDR_W-1:0]   reg_addr,
    output reg  [DATA_W-1:0]   reg_wdata,
    input  wire [DATA_W-1:0]   reg_rdata
);

    // Synchronize SPI signals to system clock domain
    reg [2:0] sclk_sync, cs_sync, mosi_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b0;
            cs_sync   <= 3'b111;
            mosi_sync <= 3'b0;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_sync   <= {cs_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[1:0], mosi};
        end
    end

    wire sclk_rise = (sclk_sync[2:1] == 2'b01);
    wire sclk_fall = (sclk_sync[2:1] == 2'b10);
    wire cs_active = ~cs_sync[2];
    wire cs_deassert = (cs_sync[2:1] == 2'b01);
    wire mosi_s = mosi_sync[2];

    // Bit counter and shift register
    reg [3:0] bit_cnt;        // 0-15 (2 bytes = 16 bits)
    reg [7:0] shift_in;       // incoming data from MOSI
    reg [7:0] shift_out;      // outgoing data to MISO
    reg       is_write;       // R/W bit from first byte
    reg       cmd_received;   // first byte fully received
    reg       data_phase;     // in data byte phase

    assign miso = cs_active ? shift_out[7] : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt      <= 4'd0;
            shift_in     <= 8'd0;
            shift_out    <= 8'd0;
            is_write     <= 1'b0;
            cmd_received <= 1'b0;
            data_phase   <= 1'b0;
            reg_wr       <= 1'b0;
            reg_rd       <= 1'b0;
            reg_addr     <= {ADDR_W{1'b0}};
            reg_wdata    <= {DATA_W{1'b0}};
        end else begin
            reg_wr <= 1'b0;  // default: no write pulse
            reg_rd <= 1'b0;  // default: no read pulse

            if (!cs_active) begin
                // CS deasserted: reset state
                bit_cnt      <= 4'd0;
                cmd_received <= 1'b0;
                data_phase   <= 1'b0;
                shift_in     <= 8'd0;
            end else begin
                // Rising edge: sample MOSI
                if (sclk_rise) begin
                    shift_in <= {shift_in[6:0], mosi_s};
                    bit_cnt  <= bit_cnt + 4'd1;

                    // After 8 bits: process command byte
                    if (bit_cnt == 4'd7 && !cmd_received) begin
                        cmd_received <= 1'b1;
                        data_phase   <= 1'b1;
                        is_write     <= shift_in[6]; // bit 7 of byte = MSB shifted in first
                        reg_addr     <= shift_in[ADDR_W-2:0]; // bits [4:0] of the byte

                        // For reads: latch reg_rdata into shift_out now
                        if (!shift_in[6]) begin // read
                            reg_rd   <= 1'b1;
                            reg_addr <= {shift_in[ADDR_W-2:0], mosi_s}; // include the last bit
                        end
                    end

                    // After 16 bits: process data byte (write)
                    if (bit_cnt == 4'd15 && cmd_received && is_write) begin
                        reg_wr    <= 1'b1;
                        reg_wdata <= {shift_in[6:0], mosi_s};
                    end
                end

                // Falling edge: shift MISO out
                if (sclk_fall && data_phase) begin
                    if (bit_cnt == 4'd8) begin
                        // Load read data at start of data phase
                        shift_out <= reg_rdata;
                    end else begin
                        shift_out <= {shift_out[6:0], 1'b0};
                    end
                end
            end
        end
    end

endmodule
