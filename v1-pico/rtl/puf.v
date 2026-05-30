/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * puf.v -- 32-bit chip ID per SPEC §3.5 REQ-SEC-001/002
 *
 * In silicon, this is the power-up state of an SRAM array (cells have
 * a slight manufacturing bias toward 0 or 1; the resulting pattern is
 * unique per die and stable across power cycles >95 % per spec).
 *
 * In RTL simulation there is no SRAM, so we model the PUF as a
 * 32-bit register loaded with a parameterizable "representative"
 * value at reset. Top-level integration overrides SIM_PUF_VALUE per
 * test if it needs distinct dies in the same simulation.
 */

`default_nettype none

module puf #(
    parameter [31:0] SIM_PUF_VALUE = 32'hA5A5_5A5A
)(
    input  wire        clk,
    input  wire        rst_n,
    output reg  [31:0] chip_id
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            chip_id <= SIM_PUF_VALUE;
        // otherwise hold; SRAM PUF is read-once at boot
    end

endmodule

`default_nettype wire
