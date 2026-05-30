/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * dds_control.v — Direct Digital Synthesis for IS excitation
 *
 * 32-bit phase accumulator drives a 256-entry quarter-wave sine LUT
 * through a symmetry decoder, producing a 10-bit unsigned code for
 * the on-chip DAC. Generates the three fixed IS frequencies of
 * SPEC §3.1 REQ-IS-001 (10 / 30 / 100 kHz) at a 1 MHz main clock.
 *
 * Phase resolution: top 10 bits of the accumulator select a logical
 * 1024-position phase (2 quadrant bits + 8 LUT-index bits). Lower 22
 * bits accumulate sub-LSB precision so the output frequencies sit
 * very close to nominal:
 *   STEP × CLK / 2^32:
 *     STEP_10K  = 32'h028F_5C29 → 9_999.9999697 Hz   (Δ ≈ −30 µHz)
 *     STEP_30K  = 32'h07AE_147B → 30_000.0000186 Hz  (Δ ≈ +19 µHz)
 *     STEP_100K = 32'h1999_999A → 100_000.0000931 Hz (Δ ≈ +93 µHz)
 * All errors well inside REQ-IS-004 (±1 %).
 *
 * Symmetry decoder (quadrant from top 2 bits of phase_acc):
 *     Q0 (00):  dac = 512 + LUT[i]
 *     Q1 (01):  dac = 512 + LUT[255−i]
 *     Q2 (10):  dac = 512 − LUT[i]
 *     Q3 (11):  dac = 512 − LUT[255−i]
 *
 * Output DAC code is registered (1-cycle latency from phase_acc),
 * helping timing closure and matching DAC sample/hold behavior.
 *
 * Sharing: one DDS instance services all three IS frequencies — IS
 * sweep is sequential (one freq settle+sample at a time).
 *
 * phase_zero output: 1-cycle pulse at the top→bottom MSB transition
 * of phase_acc, once per output period. Used by the mixer (TBD) to
 * stay phase-coherent with the excitation.
 */

`default_nettype none

module dds_control #(
    parameter CLK_FREQ_HZ = 1_000_000,
    // Pre-computed phase steps for 1 MHz clock. Override at instantiation
    // if the main clock changes (steps must equal F_OUT × 2^32 / CLK).
    parameter [31:0] STEP_10K  = 32'h028F_5C29,
    parameter [31:0] STEP_30K  = 32'h07AE_147B,
    parameter [31:0] STEP_100K = 32'h1999_999A
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,        // 1: advance phase; 0: hold
    input  wire [1:0]  freq_sel,      // 00:10k, 01:30k, 10:100k, 11:stop

    output reg  [9:0]  dac_code,      // 10-bit unsigned DAC code, centered 512
    output wire        phase_zero     // 1-cycle pulse per output period
);

    // ============================================================
    // Phase accumulator + boundary-registered freq_sel
    //   freq_sel is registered at the DDS boundary (1 cycle latency).
    //   This eliminates a sim-vs-silicon hazard where a same-timestep
    //   change to freq_sel could race the clock edge of phase_acc.
    //   The 1-cycle latency is invisible against the SPEC §7.3
    //   settling times (100 µs / 33 µs / 10 µs per frequency).
    //   Reset default 2'b11 = halted (step=0), safe boot state.
    // ============================================================
    reg  [31:0] phase_acc;
    reg  [1:0]  freq_sel_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            freq_sel_r <= 2'b11;
        else
            freq_sel_r <= freq_sel;
    end

    wire [31:0] phase_step = (freq_sel_r == 2'b00) ? STEP_10K  :
                             (freq_sel_r == 2'b01) ? STEP_30K  :
                             (freq_sel_r == 2'b10) ? STEP_100K :
                                                     32'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_acc <= 32'd0;
        else if (enable)
            phase_acc <= phase_acc + phase_step;
    end

    // ============================================================
    // Symmetry decoder
    // ============================================================
    wire        invert  = phase_acc[30];                  // Q1 or Q3 → mirror
    wire        negate  = phase_acc[31];                  // Q2 or Q3 → invert sign
    wire [7:0]  lut_in  = invert ? ~phase_acc[29:22]
                                 :  phase_acc[29:22];

    // ============================================================
    // 256-entry quarter-wave LUT
    //   sine_mag = round(511 × sin(i × π / 512)) for i = 0..255
    //   Auto-generated; synthesises as a 256×9-bit ROM.
    // ============================================================
    reg [8:0] sine_mag;

    always @(*) begin
        case (lut_in)
            8'd  0: sine_mag = 9'd  0; 8'd  1: sine_mag = 9'd  3;
            8'd  2: sine_mag = 9'd  6; 8'd  3: sine_mag = 9'd  9;
            8'd  4: sine_mag = 9'd 13; 8'd  5: sine_mag = 9'd 16;
            8'd  6: sine_mag = 9'd 19; 8'd  7: sine_mag = 9'd 22;
            8'd  8: sine_mag = 9'd 25; 8'd  9: sine_mag = 9'd 28;
            8'd 10: sine_mag = 9'd 31; 8'd 11: sine_mag = 9'd 34;
            8'd 12: sine_mag = 9'd 38; 8'd 13: sine_mag = 9'd 41;
            8'd 14: sine_mag = 9'd 44; 8'd 15: sine_mag = 9'd 47;
            8'd 16: sine_mag = 9'd 50; 8'd 17: sine_mag = 9'd 53;
            8'd 18: sine_mag = 9'd 56; 8'd 19: sine_mag = 9'd 59;
            8'd 20: sine_mag = 9'd 63; 8'd 21: sine_mag = 9'd 66;
            8'd 22: sine_mag = 9'd 69; 8'd 23: sine_mag = 9'd 72;
            8'd 24: sine_mag = 9'd 75; 8'd 25: sine_mag = 9'd 78;
            8'd 26: sine_mag = 9'd 81; 8'd 27: sine_mag = 9'd 84;
            8'd 28: sine_mag = 9'd 87; 8'd 29: sine_mag = 9'd 90;
            8'd 30: sine_mag = 9'd 94; 8'd 31: sine_mag = 9'd 97;
            8'd 32: sine_mag = 9'd100; 8'd 33: sine_mag = 9'd103;
            8'd 34: sine_mag = 9'd106; 8'd 35: sine_mag = 9'd109;
            8'd 36: sine_mag = 9'd112; 8'd 37: sine_mag = 9'd115;
            8'd 38: sine_mag = 9'd118; 8'd 39: sine_mag = 9'd121;
            8'd 40: sine_mag = 9'd124; 8'd 41: sine_mag = 9'd127;
            8'd 42: sine_mag = 9'd130; 8'd 43: sine_mag = 9'd133;
            8'd 44: sine_mag = 9'd136; 8'd 45: sine_mag = 9'd139;
            8'd 46: sine_mag = 9'd142; 8'd 47: sine_mag = 9'd145;
            8'd 48: sine_mag = 9'd148; 8'd 49: sine_mag = 9'd151;
            8'd 50: sine_mag = 9'd154; 8'd 51: sine_mag = 9'd157;
            8'd 52: sine_mag = 9'd160; 8'd 53: sine_mag = 9'd163;
            8'd 54: sine_mag = 9'd166; 8'd 55: sine_mag = 9'd169;
            8'd 56: sine_mag = 9'd172; 8'd 57: sine_mag = 9'd175;
            8'd 58: sine_mag = 9'd178; 8'd 59: sine_mag = 9'd181;
            8'd 60: sine_mag = 9'd184; 8'd 61: sine_mag = 9'd187;
            8'd 62: sine_mag = 9'd190; 8'd 63: sine_mag = 9'd193;
            8'd 64: sine_mag = 9'd196; 8'd 65: sine_mag = 9'd198;
            8'd 66: sine_mag = 9'd201; 8'd 67: sine_mag = 9'd204;
            8'd 68: sine_mag = 9'd207; 8'd 69: sine_mag = 9'd210;
            8'd 70: sine_mag = 9'd213; 8'd 71: sine_mag = 9'd216;
            8'd 72: sine_mag = 9'd218; 8'd 73: sine_mag = 9'd221;
            8'd 74: sine_mag = 9'd224; 8'd 75: sine_mag = 9'd227;
            8'd 76: sine_mag = 9'd230; 8'd 77: sine_mag = 9'd233;
            8'd 78: sine_mag = 9'd235; 8'd 79: sine_mag = 9'd238;
            8'd 80: sine_mag = 9'd241; 8'd 81: sine_mag = 9'd244;
            8'd 82: sine_mag = 9'd246; 8'd 83: sine_mag = 9'd249;
            8'd 84: sine_mag = 9'd252; 8'd 85: sine_mag = 9'd255;
            8'd 86: sine_mag = 9'd257; 8'd 87: sine_mag = 9'd260;
            8'd 88: sine_mag = 9'd263; 8'd 89: sine_mag = 9'd265;
            8'd 90: sine_mag = 9'd268; 8'd 91: sine_mag = 9'd271;
            8'd 92: sine_mag = 9'd273; 8'd 93: sine_mag = 9'd276;
            8'd 94: sine_mag = 9'd279; 8'd 95: sine_mag = 9'd281;
            8'd 96: sine_mag = 9'd284; 8'd 97: sine_mag = 9'd286;
            8'd 98: sine_mag = 9'd289; 8'd 99: sine_mag = 9'd292;
            8'd100: sine_mag = 9'd294; 8'd101: sine_mag = 9'd297;
            8'd102: sine_mag = 9'd299; 8'd103: sine_mag = 9'd302;
            8'd104: sine_mag = 9'd304; 8'd105: sine_mag = 9'd307;
            8'd106: sine_mag = 9'd309; 8'd107: sine_mag = 9'd312;
            8'd108: sine_mag = 9'd314; 8'd109: sine_mag = 9'd317;
            8'd110: sine_mag = 9'd319; 8'd111: sine_mag = 9'd322;
            8'd112: sine_mag = 9'd324; 8'd113: sine_mag = 9'd327;
            8'd114: sine_mag = 9'd329; 8'd115: sine_mag = 9'd331;
            8'd116: sine_mag = 9'd334; 8'd117: sine_mag = 9'd336;
            8'd118: sine_mag = 9'd338; 8'd119: sine_mag = 9'd341;
            8'd120: sine_mag = 9'd343; 8'd121: sine_mag = 9'd345;
            8'd122: sine_mag = 9'd348; 8'd123: sine_mag = 9'd350;
            8'd124: sine_mag = 9'd352; 8'd125: sine_mag = 9'd355;
            8'd126: sine_mag = 9'd357; 8'd127: sine_mag = 9'd359;
            8'd128: sine_mag = 9'd361; 8'd129: sine_mag = 9'd364;
            8'd130: sine_mag = 9'd366; 8'd131: sine_mag = 9'd368;
            8'd132: sine_mag = 9'd370; 8'd133: sine_mag = 9'd372;
            8'd134: sine_mag = 9'd374; 8'd135: sine_mag = 9'd377;
            8'd136: sine_mag = 9'd379; 8'd137: sine_mag = 9'd381;
            8'd138: sine_mag = 9'd383; 8'd139: sine_mag = 9'd385;
            8'd140: sine_mag = 9'd387; 8'd141: sine_mag = 9'd389;
            8'd142: sine_mag = 9'd391; 8'd143: sine_mag = 9'd393;
            8'd144: sine_mag = 9'd395; 8'd145: sine_mag = 9'd397;
            8'd146: sine_mag = 9'd399; 8'd147: sine_mag = 9'd401;
            8'd148: sine_mag = 9'd403; 8'd149: sine_mag = 9'd405;
            8'd150: sine_mag = 9'd407; 8'd151: sine_mag = 9'd409;
            8'd152: sine_mag = 9'd410; 8'd153: sine_mag = 9'd412;
            8'd154: sine_mag = 9'd414; 8'd155: sine_mag = 9'd416;
            8'd156: sine_mag = 9'd418; 8'd157: sine_mag = 9'd420;
            8'd158: sine_mag = 9'd421; 8'd159: sine_mag = 9'd423;
            8'd160: sine_mag = 9'd425; 8'd161: sine_mag = 9'd427;
            8'd162: sine_mag = 9'd428; 8'd163: sine_mag = 9'd430;
            8'd164: sine_mag = 9'd432; 8'd165: sine_mag = 9'd433;
            8'd166: sine_mag = 9'd435; 8'd167: sine_mag = 9'd437;
            8'd168: sine_mag = 9'd438; 8'd169: sine_mag = 9'd440;
            8'd170: sine_mag = 9'd441; 8'd171: sine_mag = 9'd443;
            8'd172: sine_mag = 9'd445; 8'd173: sine_mag = 9'd446;
            8'd174: sine_mag = 9'd448; 8'd175: sine_mag = 9'd449;
            8'd176: sine_mag = 9'd451; 8'd177: sine_mag = 9'd452;
            8'd178: sine_mag = 9'd454; 8'd179: sine_mag = 9'd455;
            8'd180: sine_mag = 9'd456; 8'd181: sine_mag = 9'd458;
            8'd182: sine_mag = 9'd459; 8'd183: sine_mag = 9'd461;
            8'd184: sine_mag = 9'd462; 8'd185: sine_mag = 9'd463;
            8'd186: sine_mag = 9'd465; 8'd187: sine_mag = 9'd466;
            8'd188: sine_mag = 9'd467; 8'd189: sine_mag = 9'd468;
            8'd190: sine_mag = 9'd470; 8'd191: sine_mag = 9'd471;
            8'd192: sine_mag = 9'd472; 8'd193: sine_mag = 9'd473;
            8'd194: sine_mag = 9'd474; 8'd195: sine_mag = 9'd476;
            8'd196: sine_mag = 9'd477; 8'd197: sine_mag = 9'd478;
            8'd198: sine_mag = 9'd479; 8'd199: sine_mag = 9'd480;
            8'd200: sine_mag = 9'd481; 8'd201: sine_mag = 9'd482;
            8'd202: sine_mag = 9'd483; 8'd203: sine_mag = 9'd484;
            8'd204: sine_mag = 9'd485; 8'd205: sine_mag = 9'd486;
            8'd206: sine_mag = 9'd487; 8'd207: sine_mag = 9'd488;
            8'd208: sine_mag = 9'd489; 8'd209: sine_mag = 9'd490;
            8'd210: sine_mag = 9'd491; 8'd211: sine_mag = 9'd492;
            8'd212: sine_mag = 9'd492; 8'd213: sine_mag = 9'd493;
            8'd214: sine_mag = 9'd494; 8'd215: sine_mag = 9'd495;
            8'd216: sine_mag = 9'd496; 8'd217: sine_mag = 9'd496;
            8'd218: sine_mag = 9'd497; 8'd219: sine_mag = 9'd498;
            8'd220: sine_mag = 9'd499; 8'd221: sine_mag = 9'd499;
            8'd222: sine_mag = 9'd500; 8'd223: sine_mag = 9'd501;
            8'd224: sine_mag = 9'd501; 8'd225: sine_mag = 9'd502;
            8'd226: sine_mag = 9'd502; 8'd227: sine_mag = 9'd503;
            8'd228: sine_mag = 9'd503; 8'd229: sine_mag = 9'd504;
            8'd230: sine_mag = 9'd505; 8'd231: sine_mag = 9'd505;
            8'd232: sine_mag = 9'd505; 8'd233: sine_mag = 9'd506;
            8'd234: sine_mag = 9'd506; 8'd235: sine_mag = 9'd507;
            8'd236: sine_mag = 9'd507; 8'd237: sine_mag = 9'd508;
            8'd238: sine_mag = 9'd508; 8'd239: sine_mag = 9'd508;
            8'd240: sine_mag = 9'd509; 8'd241: sine_mag = 9'd509;
            8'd242: sine_mag = 9'd509; 8'd243: sine_mag = 9'd509;
            8'd244: sine_mag = 9'd510; 8'd245: sine_mag = 9'd510;
            8'd246: sine_mag = 9'd510; 8'd247: sine_mag = 9'd510;
            8'd248: sine_mag = 9'd510; 8'd249: sine_mag = 9'd511;
            8'd250: sine_mag = 9'd511; 8'd251: sine_mag = 9'd511;
            8'd252: sine_mag = 9'd511; 8'd253: sine_mag = 9'd511;
            8'd254: sine_mag = 9'd511; 8'd255: sine_mag = 9'd511;
            default: sine_mag = 9'd0;
        endcase
    end

    // ============================================================
    // DAC output register (10-bit unsigned, centered at 512)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dac_code <= 10'd512;
        else if (negate)
            dac_code <= 10'd512 - {1'b0, sine_mag};
        else
            dac_code <= 10'd512 + {1'b0, sine_mag};
    end

    // ============================================================
    // phase_zero — 1-cycle pulse on MSB 1→0 transition
    // ============================================================
    reg msb_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            msb_prev <= 1'b0;
        else if (enable)
            msb_prev <= phase_acc[31];
    end

    assign phase_zero = msb_prev & ~phase_acc[31];

endmodule

`default_nettype wire
