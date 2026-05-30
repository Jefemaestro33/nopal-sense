/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * por_bod.v -- Power-on reset + brown-out logic per SPEC §3.4 REQ-SM-004
 *
 * Runs in the always-on 32 kHz domain. When vdd_ok asserts (VDD stable
 * above brown-out threshold), holds rst_n low for POR_HOLD_CYCLES
 * 32 kHz ticks to give analog domains time to stabilize, then releases
 * reset. If vdd_ok drops at any time, rst_n is async-asserted
 * immediately and the hold counter restarts.
 *
 * Default POR_HOLD_CYCLES = 1024 (~31 ms at 32 kHz, matches SPEC §7.1
 * "First SPI transaction allowed: 10 ms after VDD stable" with margin).
 * Test override: drop to a small value for fast sim.
 *
 * The actual vdd_ok signal comes from an analog brown-out detector
 * (TBD analog block); this module models the digital side only.
 */

`default_nettype none

module por_bod #(
    parameter POR_HOLD_CYCLES = 1024
)(
    input  wire        clk_32k,
    input  wire        vdd_ok,
    output reg         rst_n
);

    reg [10:0] hold_counter;

    always @(posedge clk_32k or negedge vdd_ok) begin
        if (!vdd_ok) begin
            rst_n         <= 1'b0;
            hold_counter  <= 11'd0;
        end else if (hold_counter < POR_HOLD_CYCLES[10:0]) begin
            rst_n         <= 1'b0;
            hold_counter  <= hold_counter + 11'd1;
        end else begin
            rst_n         <= 1'b1;
        end
    end

endmodule

`default_nettype wire
