/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module reg_bank #(
    parameter ADDR_W = 5,
    parameter DATA_W = 16
) (
    input  wire                 clk,
    input  wire                 rst_n,

    // SPI slave interface
    input  wire                 wr_en,
    input  wire                 rd_en,
    input  wire [ADDR_W-1:0]   addr,
    input  wire [DATA_W-1:0]   wdata,
    output reg  [DATA_W-1:0]   rdata,

    // Hardware write ports (from measurement engines)
    input  wire                 hw_status_wr,
    input  wire [DATA_W-1:0]   hw_status,
    input  wire                 hw_sensor_wr,
    input  wire [DATA_W-1:0]   hw_h10_h20,
    input  wire [DATA_W-1:0]   hw_h30_temp,
    input  wire [DATA_W-1:0]   hw_ec_freq,
    input  wire [DATA_W-1:0]   hw_battery,
    input  wire                 hw_is_wr,
    input  wire [DATA_W-1:0]   hw_z_mag_10k,
    input  wire [DATA_W-1:0]   hw_z_phase_10k,
    input  wire [DATA_W-1:0]   hw_z_mag_30k,
    input  wire [DATA_W-1:0]   hw_z_phase_30k,
    input  wire [DATA_W-1:0]   hw_z_mag_100k,
    input  wire [DATA_W-1:0]   hw_z_phase_100k,
    input  wire                 hw_diag_wr,
    input  wire [DATA_W-1:0]   hw_diag_err,
    input  wire [DATA_W-1:0]   hw_diag_time,
    input  wire [DATA_W-1:0]   hw_diag_curr,

    // Live mirrors for read-only registers driven outside reg_bank
    // (audit fix 2026-05-29: STATUS / ALERT_FLAGS / PUF_ID readable
    // via SPI per SPEC §5.1, §5.3, §5.8 — the prior revision wired
    // these to local storage that was never updated).
    input  wire [DATA_W-1:0]   live_status,
    input  wire [7:0]          live_alert_flags,
    input  wire [31:0]         live_chip_id,

    // Read-out ports for other modules
    output wire [DATA_W-1:0]   ctrl_reg,
    output wire [DATA_W-1:0]   trigger_reg,
    output wire [DATA_W-1:0]   gpio_sw_ctrl_reg,
    output wire [DATA_W-1:0]   sched_period_reg,
    output wire [DATA_W-1:0]   sched_warmup_reg
);

    // Register storage: 32 x 16-bit
    reg [DATA_W-1:0] regs [0:31];

    // Address map (per SPEC_FROZEN.md §5)
    localparam A_CTRL        = 5'h00;
    localparam A_STATUS      = 5'h01;
    localparam A_ALERT_FLAGS = 5'h02;
    localparam A_TRIGGER     = 5'h03;
    localparam A_H10_H20     = 5'h04;
    localparam A_H30_TEMP    = 5'h05;
    localparam A_EC_FREQ     = 5'h06;
    localparam A_BATTERY     = 5'h07;
    localparam A_Z_MAG_10K   = 5'h08;
    localparam A_Z_PH_10K    = 5'h09;
    localparam A_Z_MAG_30K   = 5'h0A;
    localparam A_Z_PH_30K    = 5'h0B;
    localparam A_Z_MAG_100K  = 5'h0C;
    localparam A_Z_PH_100K   = 5'h0D;
    localparam A_CAL_A       = 5'h0E;
    localparam A_CAL_B       = 5'h0F;
    localparam A_CAL_ALPHA   = 5'h10;
    localparam A_CAL_TREF    = 5'h11;
    localparam A_TH_VPD      = 5'h12;
    localparam A_TH_HUM      = 5'h13;
    localparam A_TH_TEMP     = 5'h14;
    localparam A_TH_BAT      = 5'h15;
    localparam A_SCHED_PER   = 5'h16;
    localparam A_SCHED_WARM  = 5'h17;
    localparam A_GPIO_SW     = 5'h18;
    localparam A_DIAG_ERR    = 5'h19;
    localparam A_DIAG_TIME   = 5'h1A;
    localparam A_DIAG_CURR   = 5'h1B;
    localparam A_PUF_ID_LO   = 5'h1C;
    localparam A_PUF_ID_HI   = 5'h1D;
    localparam A_VERSION     = 5'h1E;
    localparam A_DEBUG       = 5'h1F;

    // Read-only mask: 1 = read-only (SPI writes ignored)
    // RO: 0x01(STATUS), 0x04-0x0D(sensor+IS), 0x19-0x1B(diag), 0x1C-0x1E(PUF+VER)
    wire [31:0] ro_mask = 32'h7E003FF2;

    // Convenience outputs
    assign ctrl_reg         = regs[A_CTRL];
    assign trigger_reg      = regs[A_TRIGGER];
    assign gpio_sw_ctrl_reg = regs[A_GPIO_SW];
    assign sched_period_reg = regs[A_SCHED_PER];
    assign sched_warmup_reg = regs[A_SCHED_WARM];

    // Reset defaults (per SPEC §5)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 16'h0000;
            regs[A_CAL_A]      <= 16'h0100; // gain = 1.0 Q8.8
            regs[A_CAL_TREF]   <= 16'h1400; // Tref = 20.0°C Q8.8
            regs[A_TH_VPD]     <= 16'h1800;
            regs[A_TH_HUM]     <= 16'h3700;
            regs[A_TH_TEMP]    <= 16'h0500;
            regs[A_TH_BAT]     <= 16'h54F0;
            regs[A_SCHED_WARM] <= 16'h0064; // 100 ms
            regs[A_VERSION]    <= 16'h0100; // v1.0
        end else begin
            // SPI writes (only to non-read-only registers)
            if (wr_en && !ro_mask[addr]) begin
                regs[addr] <= wdata;
            end

            // TRIGGER is write-only and self-clearing
            if (wr_en && addr == A_TRIGGER) begin
                regs[A_TRIGGER] <= wdata;
            end else begin
                regs[A_TRIGGER] <= 16'h0000;
            end

            // ALERT_FLAGS: write-1-to-clear behavior
            if (wr_en && addr == A_ALERT_FLAGS) begin
                regs[A_ALERT_FLAGS] <= regs[A_ALERT_FLAGS] & ~wdata;
            end

            // Hardware write ports (measurement engines update read-only regs)
            if (hw_status_wr)
                regs[A_STATUS] <= hw_status;

            if (hw_sensor_wr) begin
                regs[A_H10_H20]  <= hw_h10_h20;
                regs[A_H30_TEMP] <= hw_h30_temp;
                regs[A_EC_FREQ]  <= hw_ec_freq;
                regs[A_BATTERY]  <= hw_battery;
            end

            if (hw_is_wr) begin
                regs[A_Z_MAG_10K]  <= hw_z_mag_10k;
                regs[A_Z_PH_10K]   <= hw_z_phase_10k;
                regs[A_Z_MAG_30K]  <= hw_z_mag_30k;
                regs[A_Z_PH_30K]   <= hw_z_phase_30k;
                regs[A_Z_MAG_100K] <= hw_z_mag_100k;
                regs[A_Z_PH_100K]  <= hw_z_phase_100k;
            end

            if (hw_diag_wr) begin
                regs[A_DIAG_ERR]  <= hw_diag_err;
                regs[A_DIAG_TIME] <= hw_diag_time;
                regs[A_DIAG_CURR] <= hw_diag_curr;
            end
        end
    end

    // Read port (active on rd_en, latched for SPI slave)
    //   STATUS, ALERT_FLAGS, PUF_ID_LO/HI are mirrors of live
    //   external state -- the in-array regs[] slot for these
    //   addresses is unused (kept for ro_mask + symmetry).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdata <= 16'h0000;
        else if (rd_en) begin
            case (addr)
                A_STATUS:      rdata <= live_status;
                A_ALERT_FLAGS: rdata <= {8'd0, live_alert_flags};
                A_PUF_ID_LO:   rdata <= live_chip_id[15:0];
                A_PUF_ID_HI:   rdata <= live_chip_id[31:16];
                default:       rdata <= regs[addr];
            endcase
        end
    end

endmodule
