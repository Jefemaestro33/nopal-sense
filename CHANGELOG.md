# Changelog

## 2026-05-13 — Post-PDK reconciliation

- OQ-006 resolved → Option B (10 kHz / 30 kHz / 100 kHz bio-band)
- TIA range fixed to 100 Ω – 30 kΩ with 3 gain levels (1×/10×/100×)
- All docs reconciled to workshop slot 88-pin, 3.3V single rail, Final Chip Review Aug 28
- Stripped pitch-deck framing across docs

## 2026-05-08 — Strategic clarifications pre-kickoff

- Public chip scope clarified for PICO review
- v1 priority strategy defined: P1 (IS+ADC+SPI) / P2 (humidity, EC, MUX) / P3 (power switches and bridge support)
- README rewritten with platform framing
- Internal research framing moved to private project notes

## 2026-05-07 — Repo split & PDK reality alignment

- Created `nopal-sense` as standalone chipathon repo (split from `open-silicon-mx`)
- Apache 2.0 license adopted (PICO requirement)
- Architectural reality checks: voltage 3.3V single rail (not 1.8V+3.3V), workshop slot 88-pin (not QFN-40), die 2935×2935 µm
- Pin assignment trimmed from 24 to 20 digital signals for workshop-slot fit
- Open Questions OQ-006 through OQ-009 added

## 2026-04-19 — Repository consolidation (pre-split)

- Moved PICO_APPLICATION.md and spi_slave.v to `v1-pico/`
- Deleted obsolete digital-only design (805 lines)

## 2026-04-18 — Strategic pivot to mixed-signal

- Pivoted from digital-only to mixed-signal with impedance spectroscopy
- Created: SPEC_FROZEN.md (75+ reqs), ARCHITECTURE.md, PIN_ASSIGNMENT.md
- Python golden model: 1212 lines, 8/8 tests passing
- Key decisions: 14-bit SAR ADC, shared ADC (IS+sensors), internal RC osc, simple PUF, dual clock domain

## 2026-04-10 — Day 1

- PICO Chipathon 2026 application submitted
- Tooling installed (IIC-OSIC-TOOLS, OpenLane, cocotb, Verilator)
