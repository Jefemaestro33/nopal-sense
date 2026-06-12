/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_slave #(
    parameter ADDR_W = 5,
    parameter DATA_W = 16
) (
    input  wire                 clk,
    input  wire                 rst_n,

    // SPI pins
    input  wire                 sclk,
    input  wire                 cs_n,
    input  wire                 mosi,
    output wire                 miso,

    // Register interface
    output reg                  reg_wr,
    output reg                  reg_rd,
    output reg  [ADDR_W-1:0]   reg_addr,
    output reg  [DATA_W-1:0]   reg_wdata,
    input  wire [DATA_W-1:0]   reg_rdata
);

    // Synchronize SPI signals to system clock domain (3-stage for metastability)
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

    wire sclk_rise  = (sclk_sync[2:1] == 2'b01);
    wire sclk_fall  = (sclk_sync[2:1] == 2'b10);
    wire cs_active  = ~cs_sync[2];
    wire mosi_s     = mosi_sync[2];

    // Frame: 8-bit command + 16-bit data = 24 bits total
    // Command byte: [7] R/W_N (1=write, 0=read) | [6:5] reserved | [4:0] address
    reg [4:0]  bit_cnt;
    reg [6:0]  cmd_shift;
    reg [15:0] data_shift_in;
    reg [15:0] data_shift_out;
    reg        is_write;
    reg        cmd_done;
    reg        data_phase;

    // Keep core logic two-state. Pad-level high-Z is controlled by
    // chip_core.sv through the MISO pad output-enable.
    assign miso = data_shift_out[15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt        <= 5'd0;
            cmd_shift      <= 7'd0;
            data_shift_in  <= 16'd0;
            data_shift_out <= 16'd0;
            is_write       <= 1'b0;
            cmd_done       <= 1'b0;
            data_phase     <= 1'b0;
            reg_wr         <= 1'b0;
            reg_rd         <= 1'b0;
            reg_addr       <= {ADDR_W{1'b0}};
            reg_wdata      <= {DATA_W{1'b0}};
        end else begin
            reg_wr <= 1'b0;
            reg_rd <= 1'b0;

            if (!cs_active) begin
                bit_cnt        <= 5'd0;
                cmd_done       <= 1'b0;
                data_phase     <= 1'b0;
                cmd_shift      <= 7'd0;
                data_shift_in  <= 16'd0;
            end else begin
                // Rising edge: sample MOSI
                if (sclk_rise) begin
                    bit_cnt <= bit_cnt + 5'd1;

                    if (!cmd_done) begin
                        // Accumulating command byte (bits 7..0)
                        cmd_shift <= {cmd_shift[5:0], mosi_s};

                        if (bit_cnt == 5'd7) begin
                            cmd_done   <= 1'b1;
                            data_phase <= 1'b1;
                            is_write   <= cmd_shift[6];
                            reg_addr   <= {cmd_shift[3:0], mosi_s};

                            if (!cmd_shift[6]) begin
                                reg_rd <= 1'b1;
                            end
                        end
                    end else begin
                        // Data phase: shift in 16 bits
                        data_shift_in <= {data_shift_in[14:0], mosi_s};

                        if (bit_cnt == 5'd23 && is_write) begin
                            reg_wr    <= 1'b1;
                            reg_wdata <= {data_shift_in[14:0], mosi_s};
                        end
                    end
                end

                // Falling edge: shift MISO out
                if (sclk_fall && data_phase) begin
                    if (bit_cnt == 5'd8) begin
                        data_shift_out <= reg_rdata;
                    end else begin
                        data_shift_out <= {data_shift_out[14:0], 1'b0};
                    end
                end
            end
        end
    end

endmodule
