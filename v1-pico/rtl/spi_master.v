/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * spi_master.v -- SPI master for external FeRAM bridge per
 *                 SPEC §3.2 SC-IN-008 (bridge 2) + REQ-SI-001
 *
 * Standard SPI mode 0 (CPOL=0, CPHA=0):
 *   - SCK idles low
 *   - Master sets MOSI on falling edge (or before CS asserts)
 *   - Both master and slave sample on rising edge
 *
 * Per-byte API: assert `start` with `wdata`; module shifts 8 bits,
 * captures the 8 incoming bits in `rdata`, asserts `done` for one
 * cycle. CS_N is driven low across the entire byte; the bridge wrapper
 * (TBD) can keep CS asserted across consecutive bytes by tying
 * multiple bytes together at a higher level.
 *
 * Clock divider:
 *   SCK period = 2 × CLK_DIV cycles of clk
 *   default CLK_DIV = 2 → SCK = clk / 4 = 250 kHz at 1 MHz clk
 *   FRAM datasheet (e.g. FM25V20A) tolerates up to 40 MHz; we are
 *   nowhere near that limit.
 */

`default_nettype none

module spi_master #(
    parameter CLK_DIV = 2
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,
    output reg         done,

    // SPI pins
    output reg         sck,
    output reg         mosi,
    input  wire        miso,
    output reg         cs_n
);

    localparam [1:0] S_IDLE = 2'd0,
                     S_LOW  = 2'd1,
                     S_HIGH = 2'd2,
                     S_FIN  = 2'd3;

    reg [1:0] state;
    reg [7:0] shift;
    reg [3:0] bit_cnt;
    reg [7:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            sck      <= 1'b0;
            mosi     <= 1'b0;
            cs_n     <= 1'b1;
            done     <= 1'b0;
            rdata    <= 8'd0;
            shift    <= 8'd0;
            bit_cnt  <= 4'd0;
            div_cnt  <= 8'd0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    sck   <= 1'b0;
                    cs_n  <= 1'b1;
                    if (start) begin
                        cs_n     <= 1'b0;
                        shift    <= wdata;
                        mosi     <= wdata[7];
                        bit_cnt  <= 4'd0;
                        div_cnt  <= 8'd0;
                        state    <= S_LOW;
                    end
                end

                S_LOW: begin
                    sck  <= 1'b0;
                    mosi <= shift[7];
                    if (div_cnt >= CLK_DIV - 1) begin
                        div_cnt <= 8'd0;
                        sck     <= 1'b1;                       // rising edge
                        shift   <= {shift[6:0], miso};         // sample MISO
                        state   <= S_HIGH;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_HIGH: begin
                    sck <= 1'b1;
                    if (div_cnt >= CLK_DIV - 1) begin
                        div_cnt <= 8'd0;
                        if (bit_cnt == 4'd7) begin
                            rdata <= shift;
                            sck   <= 1'b0;
                            state <= S_FIN;
                        end else begin
                            bit_cnt <= bit_cnt + 4'd1;
                            sck     <= 1'b0;                   // falling edge
                            state   <= S_LOW;
                        end
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_FIN: begin
                    sck   <= 1'b0;
                    cs_n  <= 1'b1;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
