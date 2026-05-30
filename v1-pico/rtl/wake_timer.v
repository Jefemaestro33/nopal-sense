/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * wake_timer.v — Autonomous wake-up counter (sleep domain)
 *
 * Lives in the always-on 32 kHz domain so the main 1 MHz clock can
 * be gated off during DEEP_SLEEP without losing the wake schedule.
 * Counts up to a programmable period in minutes and emits a 1-cycle
 * wake_pulse in clk_32k. An external double-flop synchronizer in the
 * main domain (instantiated by the top-level integration, not here)
 * captures the pulse for scheduler.v's wake_pulse input.
 *
 * Inputs ctrl_enable / period_sel / alert_latched cross from main
 * domain through internal 2-flop synchronizers — caller does NOT
 * need to pre-sync.
 *
 * Period selector (CTRL[7:4] per SPEC §5.1, mapping per REQ-SM-002):
 *   0: 1 min   1: 5 min   2: 15 min   3: 1 hr   4: 4 hr   5: 24 hr
 *   6-15: reserved → default to 1 hr
 *
 * ALERT cadence (SPEC §4 Mode 2): while alert_latched is high the
 * period is overridden to ALERT_PERIOD_MIN minutes (default 1)
 * regardless of CTRL[7:4]. wake_timer is the policy holder for the
 * "continue measuring at higher frequency" requirement.
 *
 * Cadence-change semantics: if counter is already past a newly
 * selected (shorter) target after a period write or alert raise,
 * fires on the next clk_32k edge. Going to longer periods just
 * extends the remaining time — no spurious early fire.
 *
 * Power: counter is gated by enable_s; while chip_enable=0 the
 * counter holds at 0 and no wake fires.
 */

`default_nettype none

module wake_timer #(
    // 32_000 Hz × 60 s = 1_920_000 cycles per minute (nominal).
    // The real ring oscillator is ±30% (per SPEC §3.4 REQ-SM-003);
    // ±5% trimmed accuracy comes from RC trim, not from this number.
    parameter CYCLES_PER_MIN   = 1_920_000,
    parameter ALERT_PERIOD_MIN = 1
)(
    input  wire        clk_32k,
    input  wire        rst_n,

    // Inputs from main clock domain (synced internally)
    input  wire        chip_enable,    // CTRL[0]
    input  wire [3:0]  period_sel,     // CTRL[7:4]
    input  wire        alert_latched,  // from scheduler.alert_latched

    // Output (1-cycle pulse in clk_32k domain)
    output reg         wake_pulse
);

    // ============================================================
    // 2-flop synchronizers (main domain → 32k domain)
    // ============================================================
    reg [1:0] enable_sync;
    reg [1:0] alert_sync;
    reg [3:0] period_sync_meta;
    reg [3:0] period_sync_stable;

    always @(posedge clk_32k or negedge rst_n) begin
        if (!rst_n) begin
            enable_sync        <= 2'b00;
            alert_sync         <= 2'b00;
            period_sync_meta   <= 4'd0;
            period_sync_stable <= 4'd0;
        end else begin
            enable_sync        <= {enable_sync[0], chip_enable};
            alert_sync         <= {alert_sync[0], alert_latched};
            period_sync_meta   <= period_sel;
            period_sync_stable <= period_sync_meta;
        end
    end

    wire        enable_s = enable_sync[1];
    wire        alert_s  = alert_sync[1];
    wire [3:0]  period_s = period_sync_stable;

    // ============================================================
    // Target cycles — combinational LUT, constants fold at synth
    // ============================================================
    reg [31:0] target_cycles;

    always @(*) begin
        if (alert_s) begin
            target_cycles = ALERT_PERIOD_MIN * CYCLES_PER_MIN;
        end else case (period_s)
            4'd0:    target_cycles = 1    * CYCLES_PER_MIN;  // 1 min
            4'd1:    target_cycles = 5    * CYCLES_PER_MIN;  // 5 min
            4'd2:    target_cycles = 15   * CYCLES_PER_MIN;  // 15 min
            4'd3:    target_cycles = 60   * CYCLES_PER_MIN;  // 1 hr
            4'd4:    target_cycles = 240  * CYCLES_PER_MIN;  // 4 hr
            4'd5:    target_cycles = 1440 * CYCLES_PER_MIN;  // 24 hr
            default: target_cycles = 60   * CYCLES_PER_MIN;  // reserved → 1 hr
        endcase
    end

    // ============================================================
    // Counter
    //   Fires (and resets) on the clock edge where counter+1 reaches
    //   target_cycles. If counter is already past target (due to a
    //   shorter cadence being newly selected), fires immediately.
    // ============================================================
    reg [31:0] counter;

    always @(posedge clk_32k or negedge rst_n) begin
        if (!rst_n) begin
            counter    <= 32'd0;
            wake_pulse <= 1'b0;
        end else begin
            wake_pulse <= 1'b0;

            if (!enable_s) begin
                counter <= 32'd0;
            end else if (counter + 32'd1 >= target_cycles) begin
                counter    <= 32'd0;
                wake_pulse <= 1'b1;
            end else begin
                counter <= counter + 32'd1;
            end
        end
    end

endmodule

`default_nettype wire
