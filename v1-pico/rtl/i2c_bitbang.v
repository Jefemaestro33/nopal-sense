/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * i2c_bitbang.v -- bit-banged I2C master per SPEC §3.2 REQ-SI-009
 *
 * Standard I2C, 100 kHz default. v1 supports single-byte transactions
 * with embedded start + 7-bit-addr + R/W + slave-ACK + data byte +
 * master-NAK/ACK + stop. Multi-byte composition is the host's job:
 * issue separate WRITE_BYTE / READ_BYTE ops with appropriate ACK bits.
 *
 * Open-drain semantics: SDA/SCL outputs use the `_oe` signal pair to
 * drive low or release (high-Z), matching the workshop slot's bi_24t
 * pad with its `oe` control bit. External pull-ups are assumed on the
 * PCB.
 *
 * Operation codes (cmd_op):
 *   3'd0  OP_IDLE
 *   3'd1  OP_START      -- emit START condition, no data
 *   3'd2  OP_WRITE_BYTE -- shift out cmd_wdata, sample ACK -> slave_ack
 *   3'd3  OP_READ_BYTE  -- shift in 8 bits to cmd_rdata, master sends
 *                          cmd_ack as the 9th bit (0=continue, 1=NAK)
 *   3'd4  OP_STOP       -- emit STOP condition
 *
 * Timing: I2C bit period = 2 × HALF_BIT_CYCLES clk cycles, default
 * gives ~100 kHz at clk=1 MHz with HALF_BIT_CYCLES=5.
 *
 * v1 SCOPE NOTE: no clock stretching support (master ignores slave
 * holding SCL low). ATECC608 in standard speed does not stretch.
 */

`default_nettype none

module i2c_bitbang #(
    parameter HALF_BIT_CYCLES = 5  // 100 kHz at clk = 1 MHz (5 cyc * 2 = 10us = 1/100kHz)
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [2:0]  cmd_op,
    input  wire [7:0]  cmd_wdata,
    input  wire        cmd_ack,        // master ACK bit for READ_BYTE
    output reg  [7:0]  cmd_rdata,
    output reg         cmd_done,
    output reg         slave_ack,      // valid after WRITE_BYTE

    // I2C bus (open-drain via _oe)
    input  wire        sda_in,
    output reg         sda_out,
    output reg         sda_oe,
    output reg         scl_out,
    output reg         scl_oe
);

    localparam [2:0]
        OP_IDLE       = 3'd0,
        OP_START      = 3'd1,
        OP_WRITE_BYTE = 3'd2,
        OP_READ_BYTE  = 3'd3,
        OP_STOP       = 3'd4;

    localparam [3:0]
        S_IDLE   = 4'd0,
        S_START  = 4'd1,    // SDA falls while SCL high
        S_LOW    = 4'd2,    // SCL low, set/sample SDA
        S_HIGH   = 4'd3,    // SCL high, hold
        S_ACK    = 4'd4,    // slave drives SDA during 9th SCL
        S_NAK    = 4'd5,    // master drives SDA during 9th SCL
        S_STOP1  = 4'd6,    // SCL low, SDA low
        S_STOP2  = 4'd7,    // SCL high (with SDA still low)
        S_STOP3  = 4'd8,    // SDA rises while SCL high
        S_FIN    = 4'd9;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [7:0]  div_cnt;
    reg [7:0]  shift;
    reg        is_read;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            sda_out   <= 1'b1;
            sda_oe    <= 1'b0;        // released (high)
            scl_out   <= 1'b1;
            scl_oe    <= 1'b0;
            cmd_done  <= 1'b0;
            slave_ack <= 1'b0;
            cmd_rdata <= 8'd0;
            shift     <= 8'd0;
            bit_cnt   <= 4'd0;
            div_cnt   <= 8'd0;
            is_read   <= 1'b0;
        end else begin
            cmd_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    sda_oe <= 1'b0;     // bus idle (released, pull-ups bring high)
                    scl_oe <= 1'b0;
                    if (cmd_valid) begin
                        case (cmd_op)
                            OP_START:      state <= S_START;
                            OP_WRITE_BYTE: begin
                                shift   <= cmd_wdata;
                                bit_cnt <= 4'd0;
                                is_read <= 1'b0;
                                div_cnt <= 8'd0;
                                state   <= S_LOW;
                            end
                            OP_READ_BYTE: begin
                                bit_cnt <= 4'd0;
                                is_read <= 1'b1;
                                div_cnt <= 8'd0;
                                state   <= S_LOW;
                            end
                            OP_STOP: state <= S_STOP1;
                            default: state <= S_FIN;
                        endcase
                    end
                end

                S_START: begin
                    // Drive SDA low while SCL stays high
                    sda_out <= 1'b0;
                    sda_oe  <= 1'b1;
                    scl_oe  <= 1'b0;  // released high
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        // Now pull SCL low for the upcoming bit phase
                        scl_out <= 1'b0;
                        scl_oe  <= 1'b1;
                        state   <= S_FIN;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_LOW: begin
                    scl_out <= 1'b0;
                    scl_oe  <= 1'b1;
                    // For writes: master drives SDA. For reads: release SDA.
                    if (is_read) begin
                        sda_oe <= 1'b0;
                    end else begin
                        sda_out <= shift[7];
                        sda_oe  <= ~shift[7];   // open-drain: only drive when 0
                    end
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        scl_oe  <= 1'b0;        // release SCL high
                        state   <= S_HIGH;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_HIGH: begin
                    scl_oe <= 1'b0;
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        // Sample SDA for reads (or for ACK check)
                        if (is_read) begin
                            shift <= {shift[6:0], sda_in};
                        end
                        if (bit_cnt == 4'd7) begin
                            // 9th bit: slave ACK (write) or master ACK (read)
                            if (is_read) begin
                                cmd_rdata <= {shift[6:0], sda_in};
                                state     <= S_NAK;
                            end else begin
                                state <= S_ACK;
                            end
                            bit_cnt <= 4'd0;
                        end else begin
                            bit_cnt <= bit_cnt + 4'd1;
                            if (!is_read) shift <= {shift[6:0], 1'b0};
                            state <= S_LOW;
                        end
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_ACK: begin
                    scl_out <= 1'b0;
                    scl_oe  <= 1'b1;
                    sda_oe  <= 1'b0;            // release for slave to ACK
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        scl_oe  <= 1'b0;        // SCL high to sample
                        slave_ack <= ~sda_in;   // ACK = SDA low
                        state <= S_FIN;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_NAK: begin
                    scl_out <= 1'b0;
                    scl_oe  <= 1'b1;
                    sda_out <= cmd_ack;          // 0=ACK, 1=NAK
                    sda_oe  <= ~cmd_ack;
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        scl_oe  <= 1'b0;
                        state   <= S_FIN;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_STOP1: begin
                    scl_out <= 1'b0;
                    scl_oe  <= 1'b1;
                    sda_out <= 1'b0;
                    sda_oe  <= 1'b1;
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        scl_oe  <= 1'b0;          // release SCL high
                        state   <= S_STOP2;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_STOP2: begin
                    scl_oe <= 1'b0;
                    if (div_cnt >= HALF_BIT_CYCLES - 1) begin
                        div_cnt <= 8'd0;
                        sda_oe  <= 1'b0;          // release SDA high (STOP edge)
                        state   <= S_STOP3;
                    end else begin
                        div_cnt <= div_cnt + 8'd1;
                    end
                end

                S_STOP3: begin
                    sda_oe <= 1'b0;
                    scl_oe <= 1'b0;
                    state  <= S_FIN;
                end

                S_FIN: begin
                    cmd_done <= 1'b1;
                    state    <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
