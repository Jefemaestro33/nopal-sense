/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * sleep_ctrl.v -- Per-subsystem clock+power gates per ARCHITECTURE §3.4
 *
 * Takes the two coarse enables from scheduler.v and fans them out as
 * per-block enables. v1 is intentionally trivial: all analog blocks
 * come up together; sleep_ctrl provides the named hooks so v2 can
 * stagger startup (bandgap first, then VREF settle, then TIA, etc.)
 * without rewiring downstream consumers.
 *
 * current_mode is exposed for future per-mode policies (e.g. shut off
 * DDS+DAC during a sensor-only NORMAL cycle, leave on during IS_SWEEP).
 * Not yet decoded -- placeholder for v1.1.
 */

`default_nettype none

module sleep_ctrl (
    input  wire        power_analog_en,
    input  wire        power_digital_en,
    input  wire [2:0]  current_mode,    // 0:SLEEP 1:NORMAL 2:ALERT 3:VAL 4:DEBUG

    output wire        en_bandgap,
    output wire        en_adc,
    output wire        en_dds_dac,
    output wire        en_tia,
    output wire        en_mixer,
    output wire        en_clock_main
);

    /* verilator lint_off UNUSED */
    wire [2:0] mode_unused = current_mode;  // reserved for v1.1 per-mode gating
    /* verilator lint_on UNUSED */

    assign en_bandgap    = power_analog_en;
    assign en_adc        = power_analog_en;
    assign en_dds_dac    = power_analog_en;
    assign en_tia        = power_analog_en;
    assign en_mixer      = power_analog_en;
    assign en_clock_main = power_digital_en;

endmodule

`default_nettype wire
