/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * calibration.v -- Q8.8 calibration MAC per SPEC §3.3 REQ-PR-001
 *
 * Computes  y = a*x + b - alpha*(T - Tref)
 *
 * Formats per SPEC §5.4 reset values:
 *   x, t, a, b, tref : 16-bit signed Q8.8
 *   alpha            : 16-bit signed Q4.12
 *   y                : 16-bit signed Q8.8
 *
 * Two 16x16 signed multiplies happen in parallel; result is registered
 * one cycle after `start`. ARCHITECTURE §3.2 D-DP-003 says the calibration
 * MAC is a single shared unit time-multiplexed across sensor channels --
 * the time-multiplexing policy lives in the higher-level sensor read
 * controller, not here.
 *
 * Fixed-point: a*x is Q16.16, alpha*(T-Tref) is Q12.20. Each term is
 * re-expressed in Q8.8 keeping its full integer range, summed in a wide
 * accumulator, and SATURATED to the signed 16-bit Q8.8 range
 * [-128.0, +127.996]. In-range results are bit-identical to the original
 * truncating form; an out-of-range result clamps to the rail instead of
 * folding to the wrong sign. (The prior implementation wrapped; REQ-PR-001
 * only mandates the Q8.8 formula, not the overflow behavior.) This matters
 * for the sensor pipeline, where a wrapped value would read as 0.
 */

`default_nettype none

module calibration (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire signed [15:0]   x,
    input  wire signed [15:0]   t,
    input  wire signed [15:0]   cal_a,
    input  wire signed [15:0]   cal_b,
    input  wire signed [15:0]   cal_alpha,
    input  wire signed [15:0]   cal_tref,

    output reg  signed [15:0]   y,
    output reg                  done
);

    wire signed [31:0] ax_full    = cal_a * x;             // Q16.16
    wire signed [15:0] dt_q88     = t - cal_tref;          // Q8.8
    wire signed [31:0] adt_full   = cal_alpha * dt_q88;    // Q12.20

    // each term to Q8.8 keeping full integer range, sum wide, then sat
    wire signed [24:0] ax_w       = {ax_full[31], ax_full[31:8]};         // Q16.8
    wire signed [24:0] adt_w      = {{5{adt_full[31]}}, adt_full[31:12]}; // Q12.8
    wire signed [24:0] b_w        = {{9{cal_b[15]}}, cal_b};              // Q8.8
    wire signed [24:0] y_w        = ax_w + b_w - adt_w;

    wire signed [15:0] y_next     = (y_w >  25'sd32767) ? 16'sd32767  :
                                    (y_w < -25'sd32768) ? -16'sd32768 :
                                    y_w[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y    <= 16'sd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                y    <= y_next;
                done <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
