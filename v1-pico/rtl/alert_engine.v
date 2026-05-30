/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * alert_engine.v -- 8 threshold comparators per SPEC §3.3 REQ-PR-003
 *
 * Watches sensor register values against threshold registers and
 * latches per-comparator alert flags. The latched flag bits drive
 * the alert_active level signal consumed by scheduler.v (which sets
 * MODE_ALERT and asserts INT_OUT) and by wake_timer.v (which
 * switches to the 1-min ALERT cadence per SPEC §4 Mode 2).
 *
 * v1 comparator map (4 active, 4 reserved for v1.1):
 *   bit 0: H10  < TH_VPD[15:8]    soil dryness alert (low moisture
 *                                 at 10 cm depth implies vapor-
 *                                 pressure-deficit irrigation need)
 *   bit 1: H20  > TH_HUM[15:8]    saturation alert
 *   bit 2: TEMP < TH_TEMP[15:8]   freeze alert (unsigned compare)
 *   bit 3: BAT  < TH_BAT[15:8]    low battery alert
 *   bits 4-7: reserved (drive 0)
 *
 * Threshold encoding: SPEC stores TH_x as 16-bit Q8.8. The engine
 * compares only the integer byte (TH_x[15:8]) against the 8-bit
 * sensor slice; fractional precision is reserved for v1.1. Reset
 * values (per reg_bank.v) put the integer bytes at sensible
 * operational defaults: TH_VPD=0x18 (24), TH_HUM=0x37 (55),
 * TH_TEMP=0x05 (5), TH_BAT=0x54 (84).
 *
 * Flag latch semantics:
 *   alert_flags <= (alert_flags | new_alerts) & ~alert_clear
 * - alert_clear pulses come from reg_bank when the SPI host writes
 *   ALERT_FLAGS with 1-bits (write-1-to-clear). The clear and a new
 *   fire arriving in the same cycle resolve to "cleared" — but if
 *   the underlying threshold condition persists, the flag re-asserts
 *   on the NEXT cycle. Host must raise the threshold (or wait for
 *   the soil condition to resolve) to silence the alert.
 * - Reset clears all flags. But: sensor registers also reset to 0,
 *   which satisfies the below-threshold comparators (TEMP<5, BAT<84)
 *   IMMEDIATELY. So the integration contract is: scheduler.v keeps
 *   `enable=0` until is_fsm has written at least one valid sensor
 *   read. Holding enable=0 forces new_alerts=0 so flags stay clean
 *   while sensor values are still at reset defaults.
 *
 * Integration note (TBD nopal_sense_top.v): reg_bank.v owns the
 * SPI-visible ALERT_FLAGS register; this engine owns the live truth
 * of the bits. Top-level wires alert_flags here back to a 16-bit
 * mirror in reg_bank for SPI reads, and detects SPI writes to
 * ALERT_FLAGS to produce the alert_clear[7:0] pulse fed in here.
 */

`default_nettype none

module alert_engine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,

    // Sensor register contents (live mirrors from reg_bank)
    input  wire [15:0] h10_h20,         // H10 in [7:0], H20 in [15:8]
    input  wire [15:0] h30_temp,        // H30 in [7:0], TEMP in [15:8]
    input  wire [15:0] battery,         // BAT in [7:0]

    // Threshold registers (live mirrors from reg_bank)
    input  wire [15:0] th_vpd,
    input  wire [15:0] th_hum,
    input  wire [15:0] th_temp,
    input  wire [15:0] th_bat,

    // 1-bit-per-comparator clear pulse from reg_bank SPI write-1-to-clear
    input  wire [7:0]  alert_clear,

    output reg  [7:0]  alert_flags,
    output wire        alert_active
);

    // ============================================================
    // Field extraction (8-bit slices of the 16-bit sensor regs)
    // ============================================================
    wire [7:0] h10  = h10_h20[7:0];
    wire [7:0] h20  = h10_h20[15:8];
    wire [7:0] temp = h30_temp[15:8];
    wire [7:0] bat  = battery[7:0];

    // ============================================================
    // Top-byte threshold values (Q.0 effective resolution)
    // ============================================================
    wire [7:0] th_vpd_int  = th_vpd[15:8];
    wire [7:0] th_hum_int  = th_hum[15:8];
    wire [7:0] th_temp_int = th_temp[15:8];
    wire [7:0] th_bat_int  = th_bat[15:8];

    // ============================================================
    // Comparators (combinational)
    // ============================================================
    wire [7:0] cmp;
    assign cmp[0]   = (h10  < th_vpd_int);    // dry
    assign cmp[1]   = (h20  > th_hum_int);    // saturated
    assign cmp[2]   = (temp < th_temp_int);   // freeze
    assign cmp[3]   = (bat  < th_bat_int);    // low battery
    assign cmp[7:4] = 4'b0;                   // reserved

    wire [7:0] new_alerts = enable ? cmp : 8'b0;

    // ============================================================
    // Flag latch (set on new alert, clear on alert_clear pulse)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            alert_flags <= 8'd0;
        else
            alert_flags <= (alert_flags | new_alerts) & ~alert_clear;
    end

    assign alert_active = |alert_flags;

endmodule

`default_nettype wire
