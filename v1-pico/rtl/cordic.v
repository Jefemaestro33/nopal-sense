/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * cordic.v — Iterative CORDIC (vectoring mode) for IS magnitude+phase
 *
 * Computes the magnitude and phase of an I/Q sample pair from the
 * mixer output:
 *
 *     mag_out   = K · √(I² + Q²)
 *     phase_out = atan2(Q, I)  (radians, Q4.12)
 *
 * K is the CORDIC gain (≈ 1.6468 for 16 iterations) and is NOT
 * corrected here — it gets absorbed into the calibration constant
 * (cal_a in Q8.8) downstream in is_post. Saves a multiplier in
 * silicon area.
 *
 * Pre-rotation handles the i_in < 0 case (left half-plane) by mapping
 * to the right half-plane and seeding z with ±π/2; standard vectoring
 * iterations cover the rest.
 *
 * One operation = ITER_N + 3 cycles (IDLE → ITERATE×N → FINISH → IDLE).
 * The IS FSM (TBD) drives `start` once per ADC sample pair per
 * frequency point. Sharing one CORDIC across all 3 frequencies is
 * legitimate because IS sweep is sequential.
 *
 * Output convention:
 *   mag_out   18-bit signed (always ≥ 0 by construction; clamped if
 *             a residual negative slips through CORDIC rounding)
 *   phase_out 16-bit signed Q4.12, range [-π, +π]
 */

`default_nettype none

module cordic #(
    parameter DATA_W   = 14,   // I/Q input width
    parameter MAG_W    = 18,   // internal x/y datapath + magnitude output
    parameter PHASE_W  = 16,   // phase output (Q4.12)
    parameter ITER_N   = 16    // CORDIC iterations
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          start,
    input  wire signed [DATA_W-1:0]      i_in,
    input  wire signed [DATA_W-1:0]      q_in,
    output reg  signed [MAG_W-1:0]       mag_out,
    output reg  signed [PHASE_W-1:0]     phase_out,
    output reg                           done
);

    // ============================================================
    // States
    // ============================================================
    localparam [1:0] S_IDLE     = 2'd0;
    localparam [1:0] S_ITERATE  = 2'd1;
    localparam [1:0] S_FINISH   = 2'd2;

    reg [1:0] state;
    reg [4:0] iter;

    reg signed [MAG_W-1:0]   x, y;
    reg signed [PHASE_W-1:0] z;

    // ============================================================
    // Constants
    //   π/2 in Q4.12: 1.5708 × 4096 = 6434
    // ============================================================
    localparam signed [PHASE_W-1:0] PI_2_Q12     = 16'sd6434;
    localparam signed [PHASE_W-1:0] NEG_PI_2_Q12 = -16'sd6434;

    // ============================================================
    // atan(2^-i) LUT in Q4.12 (16-bit signed)
    //   Beyond i=12 atan rounds to 0 in Q4.12 — kept zero to make
    //   the case statement complete and synthesis collapse the
    //   trailing iterations cleanly.
    // ============================================================
    function automatic signed [PHASE_W-1:0] atan_lut;
        input [4:0] i;
        begin
            case (i)
                5'd0:    atan_lut = 16'sd3217;  // atan(1)       = π/4
                5'd1:    atan_lut = 16'sd1900;  // atan(1/2)
                5'd2:    atan_lut = 16'sd1003;  // atan(1/4)
                5'd3:    atan_lut = 16'sd509;
                5'd4:    atan_lut = 16'sd256;
                5'd5:    atan_lut = 16'sd128;
                5'd6:    atan_lut = 16'sd64;
                5'd7:    atan_lut = 16'sd32;
                5'd8:    atan_lut = 16'sd16;
                5'd9:    atan_lut = 16'sd8;
                5'd10:   atan_lut = 16'sd4;
                5'd11:   atan_lut = 16'sd2;
                5'd12:   atan_lut = 16'sd1;
                default: atan_lut = 16'sd0;
            endcase
        end
    endfunction

    // ============================================================
    // Sign-extend inputs to internal datapath width
    // ============================================================
    wire signed [MAG_W-1:0] i_ext =
        {{(MAG_W-DATA_W){i_in[DATA_W-1]}}, i_in};
    wire signed [MAG_W-1:0] q_ext =
        {{(MAG_W-DATA_W){q_in[DATA_W-1]}}, q_in};

    // ============================================================
    // Pre-rotation to right half-plane (combinational)
    // ============================================================
    reg signed [MAG_W-1:0]   x_init, y_init;
    reg signed [PHASE_W-1:0] z_init;

    always @(*) begin
        if (i_ext[MAG_W-1] && !q_ext[MAG_W-1]) begin
            // Quadrant II: i<0, q≥0 → rotate −π/2 → (q, −i), z = +π/2
            x_init = q_ext;
            y_init = -i_ext;
            z_init = PI_2_Q12;
        end else if (i_ext[MAG_W-1] && q_ext[MAG_W-1]) begin
            // Quadrant III: i<0, q<0 → rotate +π/2 → (−q, i), z = −π/2
            x_init = -q_ext;
            y_init = i_ext;
            z_init = NEG_PI_2_Q12;
        end else begin
            // Quadrants I and IV: i≥0 — no pre-rotation
            x_init = i_ext;
            y_init = q_ext;
            z_init = 16'sd0;
        end
    end

    // ============================================================
    // FSM + datapath
    //   Vectoring convention:
    //     if y ≥ 0: rotate clockwise — x += y>>i, y -= x>>i, z += atan
    //     if y <  0: rotate counter-cw — x -= y>>i, y += x>>i, z -= atan
    //   Non-blocking assignments use OLD x in the y update,
    //   matching the textbook semantics.
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            iter      <= 5'd0;
            x         <= {MAG_W{1'b0}};
            y         <= {MAG_W{1'b0}};
            z         <= {PHASE_W{1'b0}};
            mag_out   <= {MAG_W{1'b0}};
            phase_out <= {PHASE_W{1'b0}};
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Zero input is mathematically undefined for atan2.
                        // Short-circuit to mag=0, phase=0 to avoid the
                        // Σ atan(2^-i) ≈ 1.74 rad accumulator drift.
                        if (i_ext == {MAG_W{1'b0}} && q_ext == {MAG_W{1'b0}}) begin
                            x     <= {MAG_W{1'b0}};
                            y     <= {MAG_W{1'b0}};
                            z     <= {PHASE_W{1'b0}};
                            state <= S_FINISH;
                        end else begin
                            x     <= x_init;
                            y     <= y_init;
                            z     <= z_init;
                            iter  <= 5'd0;
                            state <= S_ITERATE;
                        end
                    end
                end

                S_ITERATE: begin
                    if (y[MAG_W-1] == 1'b0) begin
                        // y ≥ 0 → CW
                        x <= x + (y >>> iter);
                        y <= y - (x >>> iter);
                        z <= z + atan_lut(iter);
                    end else begin
                        // y < 0 → CCW
                        x <= x - (y >>> iter);
                        y <= y + (x >>> iter);
                        z <= z - atan_lut(iter);
                    end

                    if (iter == ITER_N[4:0] - 5'd1)
                        state <= S_FINISH;
                    else
                        iter <= iter + 5'd1;
                end

                S_FINISH: begin
                    // x should be non-negative by construction; clamp
                    // any residual negative to 0 to keep mag_out clean.
                    mag_out   <= x[MAG_W-1] ? {MAG_W{1'b0}} : x;
                    phase_out <= z;
                    done      <= 1'b1;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
