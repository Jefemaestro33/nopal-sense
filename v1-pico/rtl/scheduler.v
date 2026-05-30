/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * scheduler.v — Main control FSM for Nopal-Sense v1
 *
 * Orchestrates the control flow described in ARCHITECTURE §3.3 with the
 * external 5-mode contract of SPEC_FROZEN §4. Internally uses 7 sub-states
 * plus a level-based alert tracker that does NOT consume an FSM state.
 *
 *   external mode (status reg)      internal state(s)
 *   ----------------------------    -----------------------------------
 *   0 DEEP_SLEEP                    S_DEEP_SLEEP
 *   1 NORMAL                        S_WARMUP(target=NORMAL), S_SENSE,
 *                                   S_IS_SWEEP, S_FINALIZE
 *   2 ALERT                         (level: alert_latched, overlays any
 *                                    non-DEBUG, non-VALIDATION state)
 *   3 VALIDATION                    S_WARMUP(target=VALIDATION),
 *                                   S_VALIDATION
 *   4 DEBUG                         S_DEBUG
 *
 * Bugfix vs previous revision:
 *   1. VALIDATION now goes through WARMUP so analog is stable before the
 *      extended IS measurement. The pending_target register selects where
 *      WARMUP routes to (S_SENSE vs S_VALIDATION).
 *   2. ALERT is no longer a terminal FSM state. The FSM keeps cycling
 *      NORMAL while alert_latched holds the INT_OUT pin asserted and the
 *      external mode reads ALERT. wake_timer (external module) consumes
 *      alert_latched to switch its cadence (1 min vs 1 hr) per SPEC §4
 *      Mode 2.
 *
 * Mode priority (decreasing):
 *     DEBUG > VALIDATION > ALERT > NORMAL > DEEP_SLEEP
 *   operator-initiated states take precedence over system-detected.
 */

`default_nettype none

module scheduler #(
    parameter CLK_FREQ_HZ  = 1_000_000,
    parameter CYCLES_PER_MS = CLK_FREQ_HZ / 1000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Register bank interface (level inputs, sync to clk)
    input  wire [15:0] ctrl_reg,
    input  wire [15:0] trigger_reg,
    input  wire [15:0] sched_warmup_reg,

    // External events (1-cycle pulses unless noted)
    input  wire        wake_pulse,
    input  wire        alert_active,       // level: from alert_engine
    input  wire        ack_pulse,          // force-clear of alert_latched
    input  wire        debug_enter,
    input  wire        debug_exit,

    // Sub-module done signals (1-cycle pulses)
    input  wire        sensor_read_done,
    input  wire        is_done,
    input  wire        self_test_done,

    // Sub-module start pulses (1-cycle, registered)
    output reg         sensor_read_start,
    output reg         is_sweep_start,
    output reg         self_test_start,

    // Power gating
    output reg         power_analog_en,
    output reg         power_digital_en,

    // Pin INT_OUT (active low, asserted while alert latched)
    output wire        int_out_n,

    // Status outputs (consumed by status_writer)
    output reg  [2:0]  current_mode,
    output wire        status_ready,
    output wire        status_measuring,
    output wire        status_alert_active,
    output wire        status_is_done
);

    // ============================================================
    // FSM states (7 internal sub-states, 3-bit encoding)
    // ============================================================
    localparam [2:0] S_DEEP_SLEEP = 3'd0;
    localparam [2:0] S_WARMUP     = 3'd1;
    localparam [2:0] S_SENSE      = 3'd2;
    localparam [2:0] S_IS_SWEEP   = 3'd3;
    localparam [2:0] S_FINALIZE   = 3'd4;
    localparam [2:0] S_VALIDATION = 3'd5;
    localparam [2:0] S_DEBUG      = 3'd6;

    // External mode codes (SPEC §4)
    localparam [2:0] MODE_DEEP_SLEEP = 3'd0;
    localparam [2:0] MODE_NORMAL     = 3'd1;
    localparam [2:0] MODE_ALERT      = 3'd2;
    localparam [2:0] MODE_VALIDATION = 3'd3;
    localparam [2:0] MODE_DEBUG      = 3'd4;

    // WARMUP target encoding
    localparam TGT_NORMAL     = 1'b0;
    localparam TGT_VALIDATION = 1'b1;

    reg [2:0] state, next_state;
    reg       pending_target;

    // ============================================================
    // CTRL register decode (SPEC §5.1 as amended)
    // ============================================================
    wire chip_enable          = ctrl_reg[0];
    wire is_in_normal_enabled = ctrl_reg[8];

    // ============================================================
    // TRIGGER decode (self-clearing 1-cycle pulses from reg_bank)
    // ============================================================
    wire trig_read_sensors = trigger_reg[0];
    wire trig_is_sweep     = trigger_reg[1];
    wire trig_self_test    = trigger_reg[2];
    wire trig_clear_state  = trigger_reg[3];

    // ============================================================
    // is_sweep_pending — latch IS-sweep intent across WARMUP+SENSE
    // ============================================================
    reg is_sweep_pending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            is_sweep_pending <= 1'b0;
        else if (state == S_DEEP_SLEEP && trig_is_sweep)
            is_sweep_pending <= 1'b1;
        else if (state == S_FINALIZE || trig_clear_state || !chip_enable)
            is_sweep_pending <= 1'b0;
    end

    // ============================================================
    // is_done_latched — survives 1-cycle IS pulse through to FINALIZE
    // ============================================================
    reg is_done_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            is_done_latched <= 1'b0;
        else if (next_state == S_FINALIZE && state == S_IS_SWEEP)
            is_done_latched <= 1'b0;
        else if (state == S_IS_SWEEP && is_done)
            is_done_latched <= 1'b1;
        else if (state == S_DEEP_SLEEP)
            is_done_latched <= 1'b0;
    end

    // ============================================================
    // alert_latched — set by alert_active, cleared by ack_pulse
    // Drives INT_OUT pin level and ALERT mode visibility.
    // alert_engine.v is expected to lower alert_active when all
    // ALERT_FLAGS bits are cleared; ack_pulse is a redundant
    // force-clear path for robustness.
    // ============================================================
    reg alert_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            alert_latched <= 1'b0;
        else if (ack_pulse)
            alert_latched <= 1'b0;
        else if (alert_active)
            alert_latched <= 1'b1;
    end

    // ============================================================
    // pending_target — latched on WARMUP entry
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pending_target <= TGT_NORMAL;
        else if (next_state == S_WARMUP && state != S_WARMUP) begin
            if (trig_self_test)
                pending_target <= TGT_VALIDATION;
            else
                pending_target <= TGT_NORMAL;
        end
    end

    // ============================================================
    // Warmup counter — target loaded on WARMUP entry
    // ============================================================
    reg [25:0] warmup_counter;
    reg [25:0] warmup_target;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warmup_counter <= 26'd0;
            warmup_target  <= 26'd0;
        end else if (next_state == S_WARMUP && state != S_WARMUP) begin
            warmup_counter <= 26'd0;
            warmup_target  <= sched_warmup_reg * CYCLES_PER_MS;
        end else if (state == S_WARMUP) begin
            warmup_counter <= warmup_counter + 26'd1;
        end
    end

    wire warmup_done = (state == S_WARMUP) &&
                       ((warmup_target == 26'd0) ||
                        (warmup_counter >= warmup_target));

    // ============================================================
    // Next-state combinational logic
    // ============================================================
    always @(*) begin
        next_state = state;

        // Global overrides
        if (!chip_enable) begin
            next_state = S_DEEP_SLEEP;
        end else if (trig_clear_state) begin
            next_state = S_DEEP_SLEEP;
        end else case (state)

            S_DEEP_SLEEP: begin
                if (debug_enter)
                    next_state = S_DEBUG;
                else if (trig_self_test ||
                         wake_pulse    ||
                         trig_read_sensors ||
                         trig_is_sweep)
                    next_state = S_WARMUP;
            end

            S_WARMUP: begin
                if (warmup_done) begin
                    if (pending_target == TGT_VALIDATION)
                        next_state = S_VALIDATION;
                    else
                        next_state = S_SENSE;
                end
            end

            S_SENSE: begin
                if (sensor_read_done) begin
                    if (is_in_normal_enabled || is_sweep_pending)
                        next_state = S_IS_SWEEP;
                    else
                        next_state = S_FINALIZE;
                end
            end

            S_IS_SWEEP: begin
                if (is_done_latched || is_done)
                    next_state = S_FINALIZE;
            end

            S_FINALIZE: begin
                next_state = S_DEEP_SLEEP;
            end

            S_VALIDATION: begin
                if (self_test_done)
                    next_state = S_DEEP_SLEEP;
            end

            S_DEBUG: begin
                if (debug_exit)
                    next_state = S_DEEP_SLEEP;
            end

            default: next_state = S_DEEP_SLEEP;
        endcase
    end

    // ============================================================
    // State register
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_DEEP_SLEEP;
        else
            state <= next_state;
    end

    // ============================================================
    // Sub-module start pulses (1-cycle on state entry)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sensor_read_start <= 1'b0;
            is_sweep_start    <= 1'b0;
            self_test_start   <= 1'b0;
        end else begin
            sensor_read_start <= (next_state == S_SENSE)      && (state != S_SENSE);
            is_sweep_start    <= (next_state == S_IS_SWEEP)   && (state != S_IS_SWEEP);
            self_test_start   <= (next_state == S_VALIDATION) && (state != S_VALIDATION);
        end
    end

    // ============================================================
    // Power gating outputs
    // ============================================================
    always @(*) begin
        case (state)
            S_DEEP_SLEEP: begin
                power_analog_en  = 1'b0;
                power_digital_en = 1'b0;
            end
            default: begin
                power_analog_en  = 1'b1;
                power_digital_en = 1'b1;
            end
        endcase
    end

    // ============================================================
    // INT_OUT pin (active low, level-based on alert_latched)
    // ============================================================
    assign int_out_n = ~alert_latched;

    // ============================================================
    // current_mode mapping with priority:
    //   DEBUG > VALIDATION > ALERT > NORMAL > DEEP_SLEEP
    // ============================================================
    always @(*) begin
        if (state == S_DEBUG) begin
            current_mode = MODE_DEBUG;
        end else if (state == S_VALIDATION ||
                     (state == S_WARMUP && pending_target == TGT_VALIDATION)) begin
            current_mode = MODE_VALIDATION;
        end else if (alert_latched) begin
            current_mode = MODE_ALERT;
        end else case (state)
            S_DEEP_SLEEP:                                    current_mode = MODE_DEEP_SLEEP;
            S_WARMUP, S_SENSE, S_IS_SWEEP, S_FINALIZE:       current_mode = MODE_NORMAL;
            default:                                         current_mode = MODE_DEEP_SLEEP;
        endcase
    end

    // ============================================================
    // Status flags
    // ============================================================
    assign status_ready        = (state == S_DEEP_SLEEP) && !alert_latched;
    assign status_measuring    = (state == S_SENSE)      ||
                                 (state == S_IS_SWEEP)   ||
                                 (state == S_VALIDATION);
    assign status_alert_active = alert_latched;
    assign status_is_done      = is_done_latched;

endmodule

`default_nettype wire
