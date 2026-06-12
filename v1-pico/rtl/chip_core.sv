/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * chip_core.sv -- Workshop-slot pad-map wrapper for Nopal-Sense v1
 *
 * Implements the immutable port contract expected by the SSCS
 * Chipathon 2026 workshop pad-ring fork (Mauricio-xx). Maps the 20
 * bidir pads + 60 analog pads + the dedicated clk/rst_n + 1 spare
 * input pad to internal signals per PIN_ASSIGNMENT.md §3.
 *
 * Bidir map (per PIN_ASSIGNMENT.md §3.1):
 *   bidir[ 0] MOSI_S   input   (ESP32 -> chip)
 *   bidir[ 1] MISO_S   output  (chip  -> ESP32)
 *   bidir[ 2] SCK_S    input
 *   bidir[ 3] CS_S     input, active-low
 *   bidir[ 4] INT_OUT  output, active-low
 *   bidir[ 5] CS_MEM   output, active-low
 *   bidir[ 6..12] GPIO_SW[0..6] outputs (24 mA drive)
 *   bidir[13] OWIRE    bidir open-drain
 *   bidir[14] I2C_SDA  bidir open-drain
 *   bidir[15] I2C_SCL  output open-drain
 *   bidir[16] MOSI_M   output
 *   bidir[17] MISO_M   input
 *   bidir[18] SCK_M    output
 *   bidir[19] PULSE_IN / TAMPER muxed (input)
 *
 * Analog map (per PIN_ASSIGNMENT.md §3.2):
 *   analog[ 0] ELEC_A   excitation output (DAC -> buffer -> electrode A)
 *   analog[ 1] ELEC_B   sense input (electrode B -> TIA)
 *   analog[ 2] VREF_OUT bandgap reference exported
 *   analog[ 3..10] ADC_IN[0..7] external analog inputs via MUX
 *   analog[11] TEST_VBG bandgap test point
 *   analog[12..59] reserved (left unconnected at this level)
 *
 * The analog pads themselves connect to TBD analog blocks (bandgap,
 * DAC, TIA, mixer, ADC) -- this RTL wrapper does not instantiate them.
 * The digital-side ADC interface (start / mux_sel / valid / data) lives
 * inside nopal_sense_top as wires that will eventually meet the analog
 * block at the next level of hierarchy.
 *
 * Pad control bits (oe / cs / sl / ie / pu / pd) follow the per-signal
 * direction. Most outputs are CMOS fast slew; OWIRE / I2C use the oe
 * signal to implement open-drain.
 */

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS  = 1,
    parameter NUM_BIDIR_PADS  = 20,
    parameter NUM_ANALOG_PADS = 60
)(
`ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
`endif

    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_INPUT_PADS-1:0]  input_in,
    output wire [NUM_INPUT_PADS-1:0]  input_pu,
    output wire [NUM_INPUT_PADS-1:0]  input_pd,

    input  wire [NUM_BIDIR_PADS-1:0]  bidir_in,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_out,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0]  bidir_pd,

    inout  wire [NUM_ANALOG_PADS-1:0] analog
);

    // ============================================================
    // Bidir routing into nopal_sense_top
    // ============================================================
    wire        spi_sclk = bidir_in[2];
    wire        spi_cs_n = bidir_in[3];
    wire        spi_mosi = bidir_in[0];
    wire        spi_miso;

    wire        int_out_n;
    wire        clk_out;
    wire [6:0]  gpio_sw;

    wire        owire_in = bidir_in[13];
    wire        owire_out, owire_oe;
    wire        i2c_sda_in = bidir_in[14];
    wire        i2c_sda_out, i2c_sda_oe;
    wire        i2c_scl_out, i2c_scl_oe;

    wire        spi_m_sck, spi_m_mosi;
    wire        spi_m_miso = bidir_in[17];
    wire        spi_m_cs_n;

    wire        pulse_in  = bidir_in[19];
    wire        tamper_in = bidir_in[19];   // muxed via firmware bit

    // ============================================================
    // bidir_out (driver values)
    // ============================================================
    assign bidir_out[0]      = 1'b0;          // MOSI_S input, no drive
    assign bidir_out[1]      = spi_miso;
    assign bidir_out[2]      = 1'b0;          // SCK_S input
    assign bidir_out[3]      = 1'b0;          // CS_S input
    assign bidir_out[4]      = int_out_n;
    assign bidir_out[5]      = spi_m_cs_n;
    assign bidir_out[12:6]   = gpio_sw;
    assign bidir_out[13]     = owire_out;
    assign bidir_out[14]     = i2c_sda_out;
    assign bidir_out[15]     = i2c_scl_out;
    assign bidir_out[16]     = spi_m_mosi;
    assign bidir_out[17]     = 1'b0;          // MISO_M input
    assign bidir_out[18]     = spi_m_sck;
    assign bidir_out[19]     = 1'b0;          // PULSE_IN/TAMPER input

    // ============================================================
    // bidir_oe (output enables)
    //   1 = drive, 0 = release (high-Z via pad)
    // ============================================================
    assign bidir_oe[0]       = 1'b0;          // MOSI_S input
    assign bidir_oe[1]       = ~spi_cs_n;     // MISO_S drives only when selected
    assign bidir_oe[2]       = 1'b0;          // SCK_S input
    assign bidir_oe[3]       = 1'b0;          // CS_S input
    assign bidir_oe[4]       = 1'b1;          // INT_OUT drive
    assign bidir_oe[5]       = 1'b1;          // CS_MEM drive
    assign bidir_oe[12:6]    = 7'b111_1111;   // GPIO_SW always driven
    assign bidir_oe[13]      = owire_oe;
    assign bidir_oe[14]      = i2c_sda_oe;
    assign bidir_oe[15]      = i2c_scl_oe;
    assign bidir_oe[16]      = 1'b1;          // MOSI_M drive
    assign bidir_oe[17]      = 1'b0;          // MISO_M input
    assign bidir_oe[18]      = 1'b1;          // SCK_M drive
    assign bidir_oe[19]      = 1'b0;          // PULSE_IN / TAMPER input

    // ============================================================
    // Default-safe pad controls (all CMOS, fast slew, no pulls)
    // ============================================================
    assign input_pu  = '0;
    assign input_pd  = '0;
    assign bidir_cs  = '0;                    // CMOS buffer
    assign bidir_sl  = '0;                    // fast slew
    assign bidir_pu  = '0;
    assign bidir_pd  = '0;
    assign bidir_ie  = ~bidir_oe;             // input enable opposite of oe

    // ============================================================
    // Analog signals (wires only -- analog blocks are TBD)
    // ELEC_A, ELEC_B, VREF_OUT, ADC_IN, TEST_VBG would be driven /
    // sampled by analog blocks at the next level of hierarchy.
    // For pure-digital sim, these pads float.
    // ============================================================
    /* verilator lint_off UNUSED */
    wire [NUM_ANALOG_PADS-1:0] analog_unused = analog;
    /* verilator lint_on UNUSED */

    // ============================================================
    // Stub ADC interface signals (digital -> analog handoff)
    // The real ADC would drive adc_data/adc_valid in response to
    // adc_start + adc_mux_sel; for pure-digital top-level sim these
    // are tied to keep is_fsm parked in S_ADC_*_WAIT (no sweep
    // completes without ADC). Smoke tests focus on SPI + reset.
    // ============================================================
    wire [9:0]  dac_code;
    wire        dac_enable, bandgap_en, tia_en, mixer_en, adc_en;
    wire [2:0]  adc_mux_sel;
    wire        adc_start;
    wire        adc_valid = 1'b0;        // ADC stub: never asserts valid
    wire signed [13:0] adc_data = 14'sd0;

    wire        clk_32k;
    // For pure-digital sim, derive clk_32k from main by simple divider
    // (TBD: real silicon uses ring osc). For now, just tie clk_32k=clk
    // -- wake_timer's own CDC and the large CYCLES_PER_MIN parameter
    // make this safe for digital regression.
    assign clk_32k = clk;

    wire [31:0] chip_id_w;

    nopal_sense_top u_top (
        .clk(clk), .clk_32k(clk_32k), .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .int_out_n(int_out_n),
        .gpio_sw(gpio_sw),
        .clk_out(clk_out),
        .owire_in(owire_in),
        .owire_out(owire_out),
        .owire_oe(owire_oe),
        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_out(i2c_sda_out),
        .i2c_sda_oe(i2c_sda_oe),
        .i2c_scl_out(i2c_scl_out),
        .i2c_scl_oe(i2c_scl_oe),
        .spi_m_sck(spi_m_sck),
        .spi_m_mosi(spi_m_mosi),
        .spi_m_miso(spi_m_miso),
        .spi_m_cs_n(spi_m_cs_n),
        .pulse_in(pulse_in),
        .tamper_in(tamper_in),
        .dac_code(dac_code),
        .dac_enable(dac_enable),
        .bandgap_en(bandgap_en),
        .tia_en(tia_en),
        .mixer_en(mixer_en),
        .adc_en(adc_en),
        .adc_mux_sel(adc_mux_sel),
        .adc_start(adc_start),
        .adc_valid(adc_valid),
        .adc_data(adc_data),
        .chip_id_out(chip_id_w)
    );

    /* verilator lint_off UNUSED */
    wire [31:0] chip_id_unused = chip_id_w;
    wire        clk_out_unused = clk_out;
    wire        sig_unused = |{dac_code, dac_enable, bandgap_en, tia_en,
                               mixer_en, adc_en, adc_mux_sel, adc_start};
    /* verilator lint_on UNUSED */

endmodule

`default_nettype wire
