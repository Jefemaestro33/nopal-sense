/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module onewire_master #(
    parameter CLK_FREQ = 1_000_000  // 1 MHz system clock
) (
    input  wire        clk,
    input  wire        rst_n,

    // 1-Wire bus (active-low, open-drain)
    input  wire        ow_in,       // sampled value of the bus
    output reg         ow_out,      // 0 = pull low, 1 = release (external pullup)
    output reg         ow_oe,       // output enable (active-high)

    // Command interface
    input  wire        cmd_valid,   // pulse to start a command
    input  wire [2:0]  cmd_op,      // operation code (see below)
    input  wire [7:0]  cmd_wdata,   // byte to write (for WRITE_BYTE op)
    output reg  [7:0]  cmd_rdata,   // byte read (for READ_BYTE op)
    output reg         cmd_done,    // pulse when operation completes
    output reg         cmd_error,   // pulse if presence not detected

    // Status
    output reg         presence     // set after successful reset+presence
);

    // Operation codes
    localparam OP_RESET      = 3'd0;  // Reset + presence detect
    localparam OP_WRITE_BYTE = 3'd1;  // Write 8 bits (LSB first)
    localparam OP_READ_BYTE  = 3'd2;  // Read 8 bits (LSB first)
    localparam OP_WRITE_BIT  = 3'd3;  // Write 1 bit (cmd_wdata[0])
    localparam OP_READ_BIT   = 3'd4;  // Read 1 bit → cmd_rdata[0]

    // Timing constants (in clock cycles at CLK_FREQ = 1 MHz → 1 µs per tick)
    // DS18B20 protocol timing (standard speed):
    localparam T_RSTL   = 480;  // Reset low pulse: 480 µs min
    localparam T_RSTH   = 480;  // Reset high (wait for presence): 480 µs
    localparam T_PDL    = 60;   // Presence detect sample window: 60-240 µs after release
    localparam T_PDH    = 240;  // Max presence pulse end
    localparam T_SLOT   = 65;   // Time slot: 60-120 µs (we use 65 µs)
    localparam T_LOW1   = 6;    // Write-1: pull low 1-15 µs (we use 6 µs)
    localparam T_LOW0   = 60;   // Write-0: pull low 60-120 µs (we use 60 µs)
    localparam T_RDV    = 15;   // Read: sample at 15 µs after pulling low
    localparam T_REC    = 5;    // Recovery time between slots: 1+ µs (we use 5 µs)
    localparam T_RLOW   = 6;    // Read initiate: pull low 1-15 µs (we use 6 µs)

    // FSM states
    localparam S_IDLE       = 4'd0;
    localparam S_RESET_LOW  = 4'd1;
    localparam S_RESET_WAIT = 4'd2;
    localparam S_RESET_SAMP = 4'd3;
    localparam S_RESET_REC  = 4'd4;
    localparam S_WRITE_LOW  = 4'd5;
    localparam S_WRITE_HOLD = 4'd6;
    localparam S_WRITE_REC  = 4'd7;
    localparam S_READ_LOW   = 4'd8;
    localparam S_READ_SAMP  = 4'd9;
    localparam S_READ_REC   = 4'd10;
    localparam S_DONE       = 4'd11;

    reg [3:0]  state, next_state;
    reg [9:0]  timer;         // up to 1023 µs counts
    reg [2:0]  bit_idx;       // 0-7 bit counter
    reg [7:0]  shift_reg;     // byte shift register
    reg [2:0]  op_reg;        // latched operation
    reg        bit_val;       // current bit to write
    reg        sampled_bit;   // bit read from bus

    // Bus drive: open-drain — pull low or release
    always @(*) begin
        if (ow_oe)
            ow_out = 1'b0;  // driving low
        else
            ow_out = 1'b1;  // released (pullup handles high)
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            timer      <= 10'd0;
            bit_idx    <= 3'd0;
            shift_reg  <= 8'd0;
            op_reg     <= 3'd0;
            bit_val    <= 1'b0;
            sampled_bit <= 1'b0;
            ow_oe      <= 1'b0;
            cmd_done   <= 1'b0;
            cmd_error  <= 1'b0;
            cmd_rdata  <= 8'd0;
            presence   <= 1'b0;
        end else begin
            cmd_done  <= 1'b0;
            cmd_error <= 1'b0;

            case (state)
                S_IDLE: begin
                    ow_oe <= 1'b0;  // release bus
                    if (cmd_valid) begin
                        op_reg    <= cmd_op;
                        shift_reg <= cmd_wdata;
                        bit_idx   <= 3'd0;
                        case (cmd_op)
                            OP_RESET: begin
                                state <= S_RESET_LOW;
                                timer <= T_RSTL - 1;
                                ow_oe <= 1'b1;  // pull low
                            end
                            OP_WRITE_BYTE, OP_WRITE_BIT: begin
                                bit_val <= cmd_wdata[0];
                                state   <= S_WRITE_LOW;
                                timer   <= T_LOW1 - 1;  // start with short pulse
                                ow_oe   <= 1'b1;
                            end
                            OP_READ_BYTE, OP_READ_BIT: begin
                                state <= S_READ_LOW;
                                timer <= T_RLOW - 1;
                                ow_oe <= 1'b1;
                            end
                            default: begin
                                cmd_done <= 1'b1;
                            end
                        endcase
                    end
                end

                // ===== RESET SEQUENCE =====
                S_RESET_LOW: begin
                    ow_oe <= 1'b1;  // hold low
                    if (timer == 0) begin
                        ow_oe <= 1'b0;  // release
                        timer <= T_PDL - 1;
                        state <= S_RESET_WAIT;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_RESET_WAIT: begin
                    ow_oe <= 1'b0;  // released, waiting for device to pull low
                    if (timer == 0) begin
                        // Sample presence (device pulls low = present)
                        sampled_bit <= ow_in;
                        timer <= (T_RSTH - T_PDL) - 1;
                        state <= S_RESET_SAMP;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_RESET_SAMP: begin
                    ow_oe <= 1'b0;
                    if (timer == 0) begin
                        // sampled_bit: 0 = device present (pulled low), 1 = no device
                        presence  <= ~sampled_bit;
                        cmd_error <= sampled_bit;  // error if no presence
                        cmd_done  <= 1'b1;
                        state     <= S_IDLE;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                // ===== WRITE SEQUENCE =====
                S_WRITE_LOW: begin
                    ow_oe <= 1'b1;  // pulling low
                    if (timer == 0) begin
                        if (bit_val) begin
                            // Write 1: release early, wait remainder of slot
                            ow_oe <= 1'b0;
                            timer <= T_SLOT - T_LOW1 - 1;
                        end else begin
                            // Write 0: keep low for full slot
                            timer <= T_LOW0 - T_LOW1 - 1;
                        end
                        state <= S_WRITE_HOLD;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_WRITE_HOLD: begin
                    // For write-1: bus released. For write-0: still driving low.
                    if (!bit_val)
                        ow_oe <= 1'b1;
                    else
                        ow_oe <= 1'b0;

                    if (timer == 0) begin
                        ow_oe <= 1'b0;  // release
                        timer <= T_REC - 1;
                        state <= S_WRITE_REC;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_WRITE_REC: begin
                    ow_oe <= 1'b0;  // recovery
                    if (timer == 0) begin
                        // Next bit or done
                        if ((op_reg == OP_WRITE_BIT) || (bit_idx == 3'd7)) begin
                            cmd_done <= 1'b1;
                            state    <= S_IDLE;
                        end else begin
                            bit_idx   <= bit_idx + 1;
                            shift_reg <= {1'b0, shift_reg[7:1]};
                            bit_val   <= shift_reg[1];  // next bit (LSB first)
                            timer     <= T_LOW1 - 1;
                            ow_oe     <= 1'b1;
                            state     <= S_WRITE_LOW;
                        end
                    end else begin
                        timer <= timer - 1;
                    end
                end

                // ===== READ SEQUENCE =====
                S_READ_LOW: begin
                    ow_oe <= 1'b1;  // pull low (initiate read slot)
                    if (timer == 0) begin
                        ow_oe <= 1'b0;  // release — device drives
                        timer <= (T_RDV - T_RLOW) - 1;
                        state <= S_READ_SAMP;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_READ_SAMP: begin
                    ow_oe <= 1'b0;  // released, device driving
                    if (timer == 0) begin
                        // Sample the bus
                        sampled_bit <= ow_in;
                        shift_reg   <= {ow_in, shift_reg[7:1]};  // LSB first
                        timer       <= T_SLOT - T_RDV - 1;
                        state       <= S_READ_REC;
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_READ_REC: begin
                    ow_oe <= 1'b0;  // wait for slot to finish
                    if (timer == 0) begin
                        if ((op_reg == OP_READ_BIT) || (bit_idx == 3'd7)) begin
                            cmd_rdata <= shift_reg;
                            cmd_done  <= 1'b1;
                            state     <= S_IDLE;
                        end else begin
                            bit_idx <= bit_idx + 1;
                            timer   <= T_RLOW - 1;
                            ow_oe   <= 1'b1;
                            state   <= S_READ_LOW;
                        end
                    end else begin
                        timer <= timer - 1;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
