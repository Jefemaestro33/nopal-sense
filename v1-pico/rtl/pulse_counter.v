/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module pulse_counter #(
    parameter CNT_W = 32
) (
    input  wire             clk,
    input  wire             rst_n,

    input  wire             pulse_in,
    input  wire             enable,
    input  wire             clear,
    input  wire [1:0]       debounce_sel,  // 00=none, 01=1us, 10=10us, 11=100us

    output reg  [CNT_W-1:0] count,
    output reg  [15:0]      count_16       // truncated for register bank
);

    // Synchronize pulse input
    reg [2:0] pulse_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pulse_sync <= 3'b0;
        else
            pulse_sync <= {pulse_sync[1:0], pulse_in};
    end

    wire pulse_s = pulse_sync[2];

    // Debounce counter (at 1 MHz clock: 1 cycle = 1 us)
    reg [6:0] deb_cnt;
    reg       deb_state;
    reg       deb_out;

    wire [6:0] deb_threshold = (debounce_sel == 2'b00) ? 7'd0 :
                               (debounce_sel == 2'b01) ? 7'd1 :
                               (debounce_sel == 2'b10) ? 7'd10 :
                                                         7'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deb_cnt   <= 7'd0;
            deb_state <= 1'b0;
            deb_out   <= 1'b0;
        end else begin
            if (pulse_s != deb_state) begin
                if (deb_cnt >= deb_threshold) begin
                    deb_state <= pulse_s;
                    deb_out   <= pulse_s;
                    deb_cnt   <= 7'd0;
                end else begin
                    deb_cnt <= deb_cnt + 7'd1;
                end
            end else begin
                deb_cnt <= 7'd0;
                deb_out <= deb_state;
            end
        end
    end

    // Edge detection on debounced signal
    reg deb_out_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            deb_out_prev <= 1'b0;
        else
            deb_out_prev <= deb_out;
    end

    wire rising_edge = deb_out & ~deb_out_prev;

    // Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= {CNT_W{1'b0}};
            count_16 <= 16'd0;
        end else if (clear) begin
            count    <= {CNT_W{1'b0}};
            count_16 <= 16'd0;
        end else if (enable && rising_edge) begin
            count    <= count + 1'b1;
            count_16 <= count[15:0] + 1'b1;
        end
    end

endmodule
