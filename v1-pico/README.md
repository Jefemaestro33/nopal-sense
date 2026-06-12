# Nopal-Sense v1

Public PICO Chipathon design package for the Nopal-Sense mixed-signal sensor
platform.

This document intentionally stays at the chip-implementation level. Private
research strategy, deployment plans, datasets, and biological validation notes
are not part of the public PICO repo.

## Technical Summary

| Parameter | Value |
|---|---|
| Process | GlobalFoundries gf180mcuD 180 nm |
| Domain | Mixed-signal sensor-control ASIC |
| Pad ring | Workshop slot 88-pin |
| Die | 2935 x 2935 um |
| Core | 2051 x 2051 um |
| Supply | 3.3 V single rail |
| Main clock | 1 MHz target |
| Sleep clock | 32 kHz always-on target |
| Host interface | SPI slave, mode 0, 250 kHz max with current sync design |
| Digital regression | 20 module/top testbenches, 0 failures (`make all`) |

## Digital RTL

The Phase 1 digital control plane includes:

- `spi_slave.v`
- `reg_bank.v`
- `crc16.v`
- `pulse_counter.v`
- `onewire_master.v`
- `scheduler.v`
- `wake_timer.v`
- `cordic.v`
- `dds_control.v`
- `is_fsm.v`
- `alert_engine.v`
- `calibration.v`
- `moving_avg.v`
- `puf.v`
- `por_bod.v`
- `sleep_ctrl.v`
- `spi_master.v`
- `i2c_bitbang.v`
- `sensor_read_controller.v`
- `nopal_sense_top.v`
- `chip_core.sv`

Current integration status:

- Directly instantiated in `nopal_sense_top.v` (14 modules): SPI slave,
  register bank, scheduler, wake timer, DDS, IS FSM, CORDIC, alert engine,
  PUF model, sleep control, sensor-read controller, SPI master, I2C bit-bang
  master, and 1-Wire master.
- Integrated into the functional netlist as children of the sensor-read
  controller: the calibration MAC and the per-channel moving-average filter
  (so 16 functional modules are in the netlist via direct + nested instances).
- Unit-tested only, not yet in the netlist: CRC16, pulse counter, and POR/BOD.
- A full impedance sweep and a sensor MUX read are verified end-to-end at the
  top level (`tb/tb_nopal_top.v` with a behavioral ADC model), including the
  ADC-timeout fault path (STATUS.error, last-good registers preserved), the
  calibration + moving-average sensor pipeline (calibration with Q8.8
  saturation), and the alert path on real sensor data.

## Phase 1b Closure

Phase 1b integrates and verifies the digital spine end-to-end.

**Integrated (in the functional netlist):**

- MISO pad output-enable gated by chip-select (`chip_core.sv` + `spi_slave.v`).
- `is_fsm` ADC-timeout watchdog that raises STATUS.error instead of hanging.
- `sensor_read_controller` running the sensor pipeline:
  raw ADC MUX -> calibration -> per-channel moving average -> register bank.
- Shared-ADC arbitration between `is_fsm` and the sensor controller.
- Alert path evaluated on real (calibrated, averaged) sensor data.

**Verified at top level (`tb/tb_nopal_top.v` + behavioral ADC model):**

- Full 3-frequency IS sweep populates the Z registers (CORDIC magnitude/phase).
- Sensor MUX read populates the sensor registers through the full pipeline.
- Fault semantics: a stuck ADC times out (no hang); a partial/faulted read does
  not commit a partial snapshot; STATUS.error is raised; last-good registers are
  preserved.
- Calibration gain/offset/Q8.8 saturation, and moving-average warm-up vs
  steady-state.

**Deferred to Phase 1c (not started):**

- `pulse_counter` + EC-frequency wiring (the `pulse_in` pad is currently unused).
- `crc16` integration.
- `por_bod` decision: on-chip POR vs the external RST_N RC (PIN_ASSIGNMENT GL-014).
- `bridge_controller.v` for the external SPI / I2C / 1-Wire bridges.
- Real PUF (uninitialized SRAM macro) vs accepting a non-unique ID.
- 0xDE debug-opcode detection in `spi_slave.v`.
- LibreLane synthesis (RTL -> GDS) of the digital top.

**Not part of the digital phase:** the analog/AMS subsystem (bandgap, DAC, TIA,
I/Q mixer, shared SAR ADC) remains the next major phase.

## Public Architecture

Nopal-Sense v1 is organized around:

- analog measurement control;
- digital scheduling and status registers;
- host SPI access;
- low-power mode control;
- sensor and memory bridge interfaces;
- workshop-slot pin integration.

Analog implementation remains the next major project phase.

## Verification

Digital tests live in [`tb/`](tb/).

```bash
cd v1-pico/tb
make all
```

The Python reference model lives in [`sim/golden_model.py`](sim/golden_model.py).

```bash
python3 v1-pico/sim/golden_model.py --test
```

## Known Public Follow-Ups

- Add `bridge_controller.v` to decode trigger registers into external bridge commands.
- Add bridge-controller logic for external SPI / I2C / 1-Wire transactions.
- Integrate the remaining standalone support blocks (pulse counter, CRC16,
  POR/BOD) where they remain in v1 scope.
- Expand top-level integration coverage beyond current audited paths.

## Related Files

- [`SPEC_FROZEN.md`](SPEC_FROZEN.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`PIN_ASSIGNMENT.md`](PIN_ASSIGNMENT.md)
- [`rtl/`](rtl/)
- [`tb/`](tb/)
- [`sim/`](sim/)
