/*
 * adc_behavioral.v -- SIMULATION-ONLY behavioral ADC model
 *
 * NOT synthesizable, NOT part of the chip. Models the digital-side
 * handshake of the (TBD analog) SAR ADC so that top-level testbenches
 * can exercise a full IS sweep through nopal_sense_top, whose adc_*
 * ports are otherwise tied off inside the chip_core pad wrapper.
 *
 * Behavior: on each adc_start pulse, after LATENCY cycles, assert
 * adc_valid for one cycle with adc_data = I_VAL (mux 0) or Q_VAL
 * (mux != 0). When `silent` is high it never responds -- this models a
 * stuck ADC or a faulted electrode, used to exercise the is_fsm timeout.
 */

`default_nettype none

module adc_behavioral #(
    parameter integer        LATENCY = 3,
    parameter signed [13:0]  I_VAL   = 14'sd4000,
    parameter signed [13:0]  Q_VAL   = 14'sd3000
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               adc_start,
    input  wire [2:0]         adc_mux_sel,
    input  wire               silent,       // all channels stuck
    input  wire [2:0]         silent_from,  // channels >= this are stuck
    output reg                adc_valid,
    output reg  signed [13:0] adc_data
);

    wire ch_silent = silent || (adc_mux_sel >= silent_from);

    // Per-channel sample value so a sensor MUX sweep produces distinct
    // readings (ch0/ch1 keep the IS I/Q values for the IS sweep test).
    function signed [13:0] mux_value(input [2:0] ch);
        case (ch)
            3'd0:    mux_value = I_VAL;       // IS I  / H10
            3'd1:    mux_value = Q_VAL;       // IS Q  / H20
            3'd2:    mux_value = 14'sd2000;   // H30
            3'd3:    mux_value = 14'sd1000;   // temp
            3'd4:    mux_value = 14'sd500;    // battery
            default: mux_value = 14'sd0;
        endcase
    endfunction

    reg [7:0] cnt;
    reg       busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_valid <= 1'b0;
            adc_data  <= 14'sd0;
            cnt       <= 8'd0;
            busy      <= 1'b0;
        end else begin
            adc_valid <= 1'b0;
            if (adc_start && !ch_silent && !busy) begin
                busy     <= 1'b1;
                cnt      <= 8'd0;
                adc_data <= mux_value(adc_mux_sel);
            end else if (busy) begin
                if (cnt >= LATENCY[7:0] - 8'd1) begin
                    adc_valid <= 1'b1;   // 1-cycle valid pulse
                    busy      <= 1'b0;
                end else begin
                    cnt <= cnt + 8'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
