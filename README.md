# Nopal-Sense

Mixed-signal sensor platform ASIC for the IEEE SSCS PICO Open-Source
Chipathon 2026.

This public repository contains the chip implementation collateral needed for
PICO review and open-source digital development: RTL, test benches, formal
specification, architecture notes, pin assignment, and simulation utilities.
Project strategy, private research notes, datasets, and operator-side plans
live outside this public repo.

## Technical Scope

Nopal-Sense v1 is a GF180MCU mixed-signal sensor hub intended to combine:

- a host SPI register interface;
- low-power scheduling and wake control;
- sensor-support digital blocks;
- impedance-measurement control logic;
- external bridge interfaces for bring-up and validation;
- workshop-slot integration through `chip_core.sv`.

The digital RTL currently focuses on the control plane and register-access
contract. Analog blocks are specified at architecture level and are the next
major design phase.

## Repository Layout

```text
nopal-sense/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── docs/
│   ├── proposal/
│   │   ├── Nopal-Sense_Project_Proposal.md
│   │   ├── Nopal-Sense_Project_Proposal_slides.md
│   │   ├── Nopal-Sense_Project_Proposal.pptx
│   │   ├── Nopal-Sense_Project_Proposal.pdf
│   │   ├── ISSUE_UPDATE.md
│   │   └── assets/
│   └── reports/
├── scripts/
│   └── setup_docker.sh
└── v1-pico/
    ├── README.md
    ├── SPEC_FROZEN.md
    ├── ARCHITECTURE.md
    ├── PIN_ASSIGNMENT.md
    ├── rtl/
    ├── tb/
    └── sim/
```

## Current Digital Status

As of the latest public docs sync:

- 19 functional RTL modules implemented. 18 have dedicated module-level
  testbenches; the sensor-read controller is verified end-to-end in the
  top-level testbench.
- 14 modules are directly instantiated in `nopal_sense_top.v`. The calibration
  MAC and the moving-average filter are integrated into the functional netlist
  as children of the sensor-read controller (so 16 modules are in the netlist
  via direct + nested instances). Three remain unit-tested only: pulse counter,
  CRC16, and POR/BOD.
- All 20 module- and top-level Icarus testbenches pass locally with zero
  failures (`make all`). A full IS sweep and a sensor MUX read are exercised
  end-to-end at the top level with a behavioral ADC model.
- Two external audit passes completed for Phase 1 digital integration.
- P0 audit findings fixed in RTL.
- Remaining Phase 1c items before silicon freeze: integrate the pulse counter
  (EC), CRC16, and POR/BOD (or defer with a documented decision); add
  `bridge_controller.v`; decide the real PUF; add the 0xDE debug opcode; and run
  LibreLane synthesis. The analog/AMS subsystem is the separate next phase.

## Key Files

- [`v1-pico/SPEC_FROZEN.md`](v1-pico/SPEC_FROZEN.md) — public technical requirements.
- [`v1-pico/ARCHITECTURE.md`](v1-pico/ARCHITECTURE.md) — block-level design rationale.
- [`v1-pico/PIN_ASSIGNMENT.md`](v1-pico/PIN_ASSIGNMENT.md) — workshop-slot pin map.
- [`v1-pico/rtl/`](v1-pico/rtl/) — Verilog/SystemVerilog RTL.
- [`v1-pico/tb/`](v1-pico/tb/) — Icarus Verilog test benches.
- [`v1-pico/sim/golden_model.py`](v1-pico/sim/golden_model.py) — Python reference model.

## Quick Verification

```bash
cd v1-pico/tb
make all
python3 ../sim/golden_model.py --test
```

## License

- RTL and public technical specifications: Apache 2.0.
- Documentation: CC BY-SA 4.0 unless otherwise noted.

## Acknowledgments

Designed for the IEEE SSCS PICO Open-Source Chipathon 2026 using GF180MCU and
open-source EDA tooling.
