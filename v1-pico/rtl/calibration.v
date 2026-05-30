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
 * Truncation rules:
 *   a*x   -> bits [23:8] (Q8.8 result, drops top sign-extension and bottom
 *           fractional bits)
 *   alpha*(T-Tref) -> bits [27:12] (Q4.12*Q8.8 = Q12.20 -> Q8.8)
 *
 * Overflow saturation is NOT implemented; calibration coefficients are
 * assumed bounded so the integer byte of any intermediate fits the Q8.8
 * range. Out-of-range coefficients silently wrap.
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
    wire signed [15:0] ax_q88     = ax_full[23:8];         // Q8.8

    wire signed [15:0] dt_q88     = t - cal_tref;          // Q8.8

    wire signed [31:0] adt_full   = cal_alpha * dt_q88;    // Q12.20
    wire signed [15:0] adt_q88    = adt_full[27:12];       // Q8.8

    wire signed [15:0] y_next     = ax_q88 + cal_b - adt_q88;

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
