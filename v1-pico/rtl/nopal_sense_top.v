/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * nopal_sense_top.v -- Digital top of Nopal-Sense v1
 *
 * Instantiates every Phase 1a digital module and wires the data path
 * from SPI slave -> reg_bank -> scheduler -> IS-FSM -> CORDIC -> back
 * to reg_bank's hardware write ports. Alert engine watches the live
 * sensor mirrors and feeds alert_latched to scheduler + wake_timer.
 *
 * Analog interface lives at the boundary of this module:
 *   dac_code[9:0]   -> on-die DAC (analog block, TBD)
 *   adc_data[13:0]  <- on-die SAR ADC (analog block, TBD)
 *   adc_valid       <- ADC controller
 *   adc_start       -> ADC controller
 *   adc_mux_sel     -> 8-ch MUX
 *
 * Pad-level wiring (per PIN_ASSIGNMENT.md) is the job of the
 * workshop-slot wrapper chip_core.sv. This module is technology-
 * agnostic; chip_core picks bits out of bidir[19:0] and analog[59:0].
 *
 * ALERT_FLAGS plumbing:
 *   alert_engine owns the live truth (its 8-bit latch).
 *   Reads of ALERT_FLAGS via SPI return alert_engine.alert_flags.
 *   Writes of ALERT_FLAGS via SPI generate a 1-cycle alert_clear
 *   pulse fed to both alert_engine (to clear bits) and scheduler
 *   (as ack_pulse to clear the latched ALERT mode).
 *
 * I2C / FRAM / 1-Wire bridges are instantiated but their host-facing
 * triggers are routed through reg_bank's TRIGGER register (TBD
 * decoder; for v1 they are externally addressable but the high-level
 * orchestration policy lives in ESP32 firmware).
 */

`default_nettype none

module nopal_sense_top (
    input  wire        clk,           // main 1 MHz
    input  wire        clk_32k,       // sleep domain
    input  wire        rst_n,

    // SPI slave (to ESP32 host)
    input  wire        spi_sclk,
    input  wire        spi_cs_n,
    input  wire        spi_mosi,
    output wire        spi_miso,

    // Pin INT_OUT (active low, asserted in ALERT)
    output wire        int_out_n,

    // Power switches GPIO_SW[0..6]
    output wire [6:0]  gpio_sw,

    // Clock export
    output wire        clk_out,

    // 1-Wire bus
    input  wire        owire_in,
    output wire        owire_out,
    output wire        owire_oe,

    // I2C bus
    input  wire        i2c_sda_in,
    output wire        i2c_sda_out,
    output wire        i2c_sda_oe,
    output wire        i2c_scl_out,
    output wire        i2c_scl_oe,

    // SPI master (FRAM)
    output wire        spi_m_sck,
    output wire        spi_m_mosi,
    input  wire        spi_m_miso,
    output wire        spi_m_cs_n,

    // Pulse input (EC probe)
    input  wire        pulse_in,

    // Tamper (muxed with pulse_in via firmware, single pin in pad map)
    input  wire        tamper_in,

    // Analog interface to on-die analog blocks
    output wire [9:0]  dac_code,
    output wire        dac_enable,
    output wire        bandgap_en,
    output wire        tia_en,
    output wire        mixer_en,
    output wire        adc_en,
    output wire [2:0]  adc_mux_sel,
    output wire        adc_start,
    input  wire        adc_valid,
    input  wire signed [13:0] adc_data,

    // Chip identity (top-level exposed for SPI reads via PUF_ID regs)
    output wire [31:0] chip_id_out
);

    // ============================================================
    // Internal wires
    // ============================================================
    wire        reg_wr;
    wire        reg_rd;
    wire [4:0]  reg_addr;
    wire [15:0] reg_wdata;
    wire [15:0] reg_rdata;

    wire [15:0] ctrl_reg;
    wire [15:0] trigger_reg;
    wire [15:0] gpio_sw_ctrl_reg;
    wire [15:0] sched_period_reg;
    wire [15:0] sched_warmup_reg;
    wire [15:0] cal_a_reg, cal_b_reg, cal_alpha_reg, cal_tref_reg;

    // Scheduler I/O
    wire        wake_pulse_main;
    wire        is_sweep_start;
    wire        is_done;
    wire        sensor_read_start;
    wire        sensor_read_done;
    wire        self_test_start;
    wire        self_test_done;
    wire [1:0]  freq_sel_int;
    wire        dds_enable;
    wire        power_analog_en;
    wire        power_digital_en;
    wire [2:0]  current_mode;
    wire        status_ready;
    wire        status_measuring;
    wire        status_alert_active;
    wire        status_is_done;
    wire        is_error_w;          // is_fsm ADC/electrode-fault -> STATUS bit 4
    wire        sns_error_w;         // sensor_read_controller ADC fault

    // Shared-ADC arbitration + sensor_read_controller signals
    wire        is_adc_start,  sns_adc_start;
    wire [2:0]  is_adc_mux,    sns_adc_mux;
    wire        sns_busy, sns_read_done, sns_hw_sensor_wr;
    wire [15:0] sns_h10_h20, sns_h30_temp, sns_ec_freq, sns_battery;

    // CORDIC
    wire        cordic_start;
    wire signed [13:0] cordic_i_in, cordic_q_in;
    wire        cordic_done;
    wire signed [17:0] cordic_mag;
    wire signed [15:0] cordic_phase;

    // Reg_bank hardware write ports (driven by is_fsm + sensor reads)
    wire        hw_is_wr;
    wire [15:0] hw_z_mag_10k, hw_z_phase_10k;
    wire [15:0] hw_z_mag_30k, hw_z_phase_30k;
    wire [15:0] hw_z_mag_100k, hw_z_phase_100k;

    // Alert engine
    wire [15:0] h10_h20_reg, h30_temp_reg, ec_freq_reg, battery_reg;
    wire [15:0] th_vpd_reg, th_hum_reg, th_temp_reg, th_bat_reg;
    wire [7:0]  alert_flags;
    wire        alert_active;

    // SPI host write-1-to-clear of ALERT_FLAGS -> alert_clear pulse
    wire spi_write_alert_flags = reg_wr && (reg_addr == 5'h02);
    wire [7:0] alert_clear      = spi_write_alert_flags ?
                                  reg_wdata[7:0] : 8'd0;
    wire       ack_pulse        = spi_write_alert_flags &&
                                  (|reg_wdata[7:0]);

    // Debug enter (0xDE opcode detection — placeholder, requires
    // dedicated tracking inside spi_slave; v1 ties to 0)
    wire debug_enter = 1'b0;
    wire debug_exit  = 1'b0;

    // Wake_pulse CDC from 32k to main
    wire wake_pulse_32k;
    reg  wake_sync1, wake_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wake_sync1 <= 1'b0;
            wake_sync2 <= 1'b0;
        end else begin
            wake_sync1 <= wake_pulse_32k;
            wake_sync2 <= wake_sync1;
        end
    end
    assign wake_pulse_main = wake_sync1 & ~wake_sync2;  // rising-edge detect

    // ============================================================
    // SPI slave -> reg_bank
    // ============================================================
    spi_slave #(.ADDR_W(5), .DATA_W(16)) u_spi_slave (
        .clk(clk), .rst_n(rst_n),
        .sclk(spi_sclk), .cs_n(spi_cs_n),
        .mosi(spi_mosi), .miso(spi_miso),
        .reg_wr(reg_wr), .reg_rd(reg_rd),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata), .reg_rdata(reg_rdata)
    );

    // STATUS register live assembly per SPEC §5.1:
    //   bit 0 ready  bit 1 measuring  bit 2 alert_active  bit 3 is_done
    //   bit 4 error  bits 5-15 error_code (reserved for v1.1)
    wire [15:0] live_status = {
        11'd0,                // bits 15..5 reserved
        is_error_w | sns_error_w, // bit 4 error (is_fsm or sensor ADC fault)
        status_is_done,       // bit 3
        status_alert_active,  // bit 2
        status_measuring,     // bit 1
        status_ready          // bit 0
    };

    reg_bank #(.ADDR_W(5), .DATA_W(16)) u_reg_bank (
        .clk(clk), .rst_n(rst_n),
        .wr_en(reg_wr), .rd_en(reg_rd),
        .addr(reg_addr),
        .wdata(reg_wdata), .rdata(reg_rdata),
        // Hardware status writes -- unused now that STATUS is mirrored
        .hw_status_wr(1'b0), .hw_status(16'd0),
        // Sensor writes from sensor_read_controller
        .hw_sensor_wr(sns_hw_sensor_wr),
        .hw_h10_h20(sns_h10_h20), .hw_h30_temp(sns_h30_temp),
        .hw_ec_freq(sns_ec_freq), .hw_battery(sns_battery),
        // IS writes
        .hw_is_wr(hw_is_wr),
        .hw_z_mag_10k(hw_z_mag_10k),   .hw_z_phase_10k(hw_z_phase_10k),
        .hw_z_mag_30k(hw_z_mag_30k),   .hw_z_phase_30k(hw_z_phase_30k),
        .hw_z_mag_100k(hw_z_mag_100k), .hw_z_phase_100k(hw_z_phase_100k),
        // Diag writes -- TBD
        .hw_diag_wr(1'b0),
        .hw_diag_err(16'd0), .hw_diag_time(16'd0), .hw_diag_curr(16'd0),
        // Live mirrors (audit fix 2026-05-29: P0 — make STATUS,
        // ALERT_FLAGS, PUF_ID readable via SPI)
        .live_status(live_status),
        .live_alert_flags(alert_flags),
        .live_chip_id(chip_id_out),
        // Outputs
        .ctrl_reg(ctrl_reg), .trigger_reg(trigger_reg),
        .gpio_sw_ctrl_reg(gpio_sw_ctrl_reg),
        .sched_period_reg(sched_period_reg),
        .sched_warmup_reg(sched_warmup_reg),
        .cal_a_reg(cal_a_reg), .cal_b_reg(cal_b_reg),
        .cal_alpha_reg(cal_alpha_reg), .cal_tref_reg(cal_tref_reg)
    );

    // alert_engine sees the live sensor values produced by the
    // sensor_read_controller. Thresholds stay at the reg_bank reset
    // defaults for now (firmware-config read taps are a follow-up).
    assign h10_h20_reg  = sns_h10_h20;
    assign h30_temp_reg = sns_h30_temp;
    assign ec_freq_reg  = sns_ec_freq;
    assign battery_reg  = sns_battery;
    assign th_vpd_reg   = 16'h1800;
    assign th_hum_reg   = 16'h3700;
    assign th_temp_reg  = 16'h0500;
    assign th_bat_reg   = 16'h54F0;

    // ============================================================
    // Scheduler
    // ============================================================
    scheduler u_scheduler (
        .clk(clk), .rst_n(rst_n),
        .ctrl_reg(ctrl_reg),
        .trigger_reg(trigger_reg),
        .sched_warmup_reg(sched_warmup_reg),
        .wake_pulse(wake_pulse_main),
        .alert_active(alert_active),
        .ack_pulse(ack_pulse),
        .debug_enter(debug_enter),
        .debug_exit(debug_exit),
        .sensor_read_done(sensor_read_done),
        .is_done(is_done),
        .self_test_done(self_test_done),
        .sensor_read_start(sensor_read_start),
        .is_sweep_start(is_sweep_start),
        .self_test_start(self_test_start),
        .power_analog_en(power_analog_en),
        .power_digital_en(power_digital_en),
        .int_out_n(int_out_n),
        .current_mode(current_mode),
        .status_ready(status_ready),
        .status_measuring(status_measuring),
        .status_alert_active(status_alert_active),
        .status_is_done(status_is_done)
    );

    // Sensor-read controller drives the ADC MUX sweep and writes the
    // sensor registers; sensor_read_done now reflects the real read.
    assign sensor_read_done = sns_read_done;
    assign self_test_done   = is_done;

    sensor_read_controller #(.ADC_TIMEOUT(256)) u_sensor (
        .clk(clk), .rst_n(rst_n),
        .sensor_read_start(sensor_read_start),
        .sensor_read_done(sns_read_done),
        .adc_start(sns_adc_start),
        .adc_mux_sel(sns_adc_mux),
        .adc_valid(adc_valid),
        .adc_data(adc_data),
        .ec_count(16'd0),          // pulse_counter integration TBD
        .cal_a(cal_a_reg), .cal_b(cal_b_reg),
        .cal_alpha(cal_alpha_reg), .cal_tref(cal_tref_reg),
        .hw_sensor_wr(sns_hw_sensor_wr),
        .h10_h20(sns_h10_h20),
        .h30_temp(sns_h30_temp),
        .ec_freq(sns_ec_freq),
        .battery(sns_battery),
        .busy(sns_busy),
        .is_error(sns_error_w)
    );

    // Shared-ADC arbitration (ARCHITECTURE D-IS-005): the sensor
    // controller owns the ADC while reading; otherwise is_fsm drives it.
    // The scheduler sequences SENSE then IS_SWEEP, so they never overlap.
    assign adc_start   = sns_busy ? sns_adc_start : is_adc_start;
    assign adc_mux_sel = sns_busy ? sns_adc_mux   : is_adc_mux;

    // ============================================================
    // Wake timer (sleep domain)
    // ============================================================
    wake_timer u_wake_timer (
        .clk_32k(clk_32k),
        .rst_n(rst_n),
        .chip_enable(ctrl_reg[0]),
        .period_sel(ctrl_reg[7:4]),
        .alert_latched(alert_active),
        .wake_pulse(wake_pulse_32k)
    );

    // ============================================================
    // IS FSM + CORDIC + DDS
    // ============================================================
    is_fsm u_is_fsm (
        .clk(clk), .rst_n(rst_n),
        .is_sweep_start(is_sweep_start),
        .is_done(is_done),
        .freq_sel(freq_sel_int),
        .dds_enable(dds_enable),
        .adc_start(is_adc_start),
        .adc_mux_sel(is_adc_mux),
        .adc_valid(adc_valid),
        .adc_data(adc_data),
        .cordic_start(cordic_start),
        .cordic_i_in(cordic_i_in),
        .cordic_q_in(cordic_q_in),
        .cordic_done(cordic_done),
        .cordic_mag(cordic_mag),
        .cordic_phase(cordic_phase),
        .hw_is_wr(hw_is_wr),
        .hw_z_mag_10k(hw_z_mag_10k),   .hw_z_phase_10k(hw_z_phase_10k),
        .hw_z_mag_30k(hw_z_mag_30k),   .hw_z_phase_30k(hw_z_phase_30k),
        .hw_z_mag_100k(hw_z_mag_100k), .hw_z_phase_100k(hw_z_phase_100k),
        .is_error(is_error_w)
    );

    cordic u_cordic (
        .clk(clk), .rst_n(rst_n),
        .start(cordic_start),
        .i_in(cordic_i_in), .q_in(cordic_q_in),
        .mag_out(cordic_mag),
        .phase_out(cordic_phase),
        .done(cordic_done)
    );

    dds_control u_dds (
        .clk(clk), .rst_n(rst_n),
        .enable(dds_enable),
        .freq_sel(freq_sel_int),
        .dac_code(dac_code),
        .phase_zero(/* unused at top-level */)
    );

    assign dac_enable = dds_enable;

    // ============================================================
    // Alert engine
    //   audit fix 2026-05-29 (P0): gate enable with CTRL[9] =
    //   alerts_enabled. The default-zero sensor registers satisfy
    //   the below-threshold comparators (TEMP<5, BAT<84) at the very
    //   instant power_digital_en first rises, so without this gate
    //   the chip would latch spurious dry/freeze/low-bat alerts on
    //   the first NORMAL cycle. ESP32 firmware writes CTRL[9]=1
    //   only after a valid sensor read has populated reg_bank.
    //   See SPEC §5.1 CTRL bit 9 amendment.
    // ============================================================
    wire alerts_enabled = ctrl_reg[9];

    alert_engine u_alert (
        .clk(clk), .rst_n(rst_n),
        .enable(power_digital_en & alerts_enabled),
        .h10_h20(h10_h20_reg),
        .h30_temp(h30_temp_reg),
        .battery(battery_reg),
        .th_vpd(th_vpd_reg), .th_hum(th_hum_reg),
        .th_temp(th_temp_reg), .th_bat(th_bat_reg),
        .alert_clear(alert_clear),
        .alert_flags(alert_flags),
        .alert_active(alert_active)
    );

    // ============================================================
    // PUF (chip ID)
    // ============================================================
    puf u_puf (
        .clk(clk), .rst_n(rst_n),
        .chip_id(chip_id_out)
    );

    // ============================================================
    // Sleep control (per-block enable fan-out)
    // ============================================================
    sleep_ctrl u_sleep (
        .power_analog_en(power_analog_en),
        .power_digital_en(power_digital_en),
        .current_mode(current_mode),
        .en_bandgap(bandgap_en),
        .en_adc(adc_en),
        .en_dds_dac(/* covered by dac_enable */),
        .en_tia(tia_en),
        .en_mixer(mixer_en),
        .en_clock_main(/* unused at top */)
    );

    // ============================================================
    // External bus bridges (kept idle in v1 -- ESP32 firmware will
    // command them later via reg_bank-mediated triggers).
    // ============================================================
    spi_master u_spi_m (
        .clk(clk), .rst_n(rst_n),
        .start(1'b0), .wdata(8'd0),
        .rdata(/* unused */), .done(/* unused */),
        .sck(spi_m_sck), .mosi(spi_m_mosi),
        .miso(spi_m_miso), .cs_n(spi_m_cs_n)
    );

    i2c_bitbang u_i2c (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(1'b0), .cmd_op(3'd0),
        .cmd_wdata(8'd0), .cmd_ack(1'b0),
        .cmd_rdata(/* unused */),
        .cmd_done(/* unused */),
        .slave_ack(/* unused */),
        .sda_in(i2c_sda_in),
        .sda_out(i2c_sda_out), .sda_oe(i2c_sda_oe),
        .scl_out(i2c_scl_out), .scl_oe(i2c_scl_oe)
    );

    onewire_master u_owire (
        .clk(clk), .rst_n(rst_n),
        .ow_in(owire_in),
        .ow_out(owire_out), .ow_oe(owire_oe),
        .cmd_valid(1'b0), .cmd_op(3'd0),
        .cmd_wdata(8'd0),
        .cmd_rdata(/* unused */),
        .cmd_done(/* unused */),
        .cmd_error(/* unused */),
        .presence(/* unused */)
    );

    // ============================================================
    // GPIO power switches (driven from GPIO_SW_CTRL register)
    // ============================================================
    assign gpio_sw = gpio_sw_ctrl_reg[6:0];

    // Clock export: pass through main clock when digital powered
    assign clk_out = clk & power_digital_en;

endmodule

`default_nettype wire
