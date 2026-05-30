/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * moving_avg.v -- power-of-2 moving average per SPEC §3.3 REQ-PR-002
 *
 * Maintains a 16-deep circular buffer of 16-bit signed samples and
 * computes the running average over a 4 / 8 / 16-sample window.
 * Per ARCHITECTURE §3.2 D-DP-002 the average uses an arithmetic
 * right shift, so no divider is needed.
 *
 * Update rule (textbook running sum):
 *   new_sum = sum - buf[wptr] + sample_in
 *   buf[wptr] <= sample_in
 *   wptr <= (wptr + 1) & (N - 1)
 *   avg <= new_sum >>> log2(N)
 *
 * Window selector:
 *   2'd0 -> N = 4
 *   2'd1 -> N = 8
 *   2'd2 -> N = 16
 *   2'd3 -> reserved, defaults to N = 4
 *
 * Window changes reset buf+sum+avg so the filter does not produce
 * stale samples after a stride change.
 *
 * Warm-up: for the first N samples after reset/window-change the
 * average is artificially low (sum subtracts buf entries that still
 * hold 0). Acceptable for v1 -- the higher-level controller should
 * discard the early outputs if needed.
 */

`default_nettype none

module moving_avg #(
    parameter DATA_W = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       enable,
    input  wire [1:0]                 window_sel,
    input  wire                       sample_valid,
    input  wire signed [DATA_W-1:0]   sample_in,

    output reg  signed [DATA_W-1:0]   avg_out
);

    // 20-bit signed sum (16 entries of 16-bit signed = max 20-bit)
    reg signed [DATA_W+3:0] sum;
    reg signed [DATA_W-1:0] buffer [0:15];
    reg [3:0]               wptr;
    reg [1:0]               window_prev;

    // Window decode
    reg [3:0] N_mask;
    reg [2:0] log2_N;
    always @(*) begin
        case (window_sel)
            2'd0:    begin N_mask = 4'd3;  log2_N = 3'd2; end  // N=4
            2'd1:    begin N_mask = 4'd7;  log2_N = 3'd3; end  // N=8
            2'd2:    begin N_mask = 4'd15; log2_N = 3'd4; end  // N=16
            default: begin N_mask = 4'd3;  log2_N = 3'd2; end  // reserved -> N=4
        endcase
    end

    integer i;
    reg signed [DATA_W+3:0] new_sum_calc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum         <= {(DATA_W+4){1'b0}};
            wptr        <= 4'd0;
            avg_out     <= {DATA_W{1'b0}};
            window_prev <= 2'd0;
            for (i = 0; i < 16; i = i + 1)
                buffer[i] <= {DATA_W{1'b0}};
        end else if (window_sel != window_prev) begin
            // Window change -> hard reset of filter state
            sum         <= {(DATA_W+4){1'b0}};
            wptr        <= 4'd0;
            avg_out     <= {DATA_W{1'b0}};
            window_prev <= window_sel;
            for (i = 0; i < 16; i = i + 1)
                buffer[i] <= {DATA_W{1'b0}};
        end else if (enable && sample_valid) begin
            // Compute new sum inline using current (pre-NBA) values
            new_sum_calc = sum -
                {{4{buffer[wptr][DATA_W-1]}}, buffer[wptr]} +
                {{4{sample_in[DATA_W-1]}}, sample_in};
            sum           <= new_sum_calc;
            buffer[wptr]  <= sample_in;
            wptr          <= (wptr + 4'd1) & N_mask;
            avg_out       <= new_sum_calc >>> log2_N;
        end
    end

endmodule

`default_nettype wire
