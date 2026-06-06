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

- 18 functional RTL modules plus top-level integration and workshop wrapper.
- 185/185 Icarus regression assertions passing.
- Two external audit passes completed for Phase 1 digital integration.
- P0 audit findings fixed in RTL.
- Remaining public P1 items are integration hardening before silicon freeze:
  bridge-controller logic, ADC/sensor behavioral stubs, and broader top-level
  coverage.

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
