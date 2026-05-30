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
| Padring | Workshop slot 88-pin |
| Die | 2935 x 2935 um |
| Core | 2051 x 2051 um |
| Supply | 3.3 V single rail |
| Main clock | 1 MHz target |
| Sleep clock | 32 kHz always-on target |
| Host interface | SPI slave, mode 0, 250 kHz max with current sync design |
| Digital regression | 184/184 assertions passing |

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
- `nopal_sense_top.v`
- `chip_core.sv`

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
- Fix FRAM SPI chip-select pin assignment before silicon freeze.
- Add ADC / sensor behavioral stubs for fuller top-level verification.
- Expand top-level integration coverage beyond current audited paths.

## Related Files

- [`SPEC_FROZEN.md`](SPEC_FROZEN.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`PIN_ASSIGNMENT.md`](PIN_ASSIGNMENT.md)
- [`rtl/`](rtl/)
- [`tb/`](tb/)
- [`sim/`](sim/)
