# Changelog

Historial de cambios mayores del proyecto Nopal-Sense.

## 2026-05-07 — Repo split & PDK reality alignment

### Repository
- **Created `nopal-sense` repo** as standalone home for the chipathon project
- Imported `v1-pico/` and `v2-commercial/` from `open-silicon-mx`
- Imported full project documentation as `docs/briefing.md`, `docs/plan.md`, `docs/calendario.md`
- Original `open-silicon-mx` renamed to `mx-silicon-research` and made private (research notes only)
- Apache 2.0 license adopted (PICO Chipathon requirement)

### Architectural reality checks documented
After re-validating the spec against the official Chipathon 2026 repo, the
following inconsistencies were detected and resolution paths proposed:

- **Frecuencias IS:** SPEC original 1k/100k/1M Hz solo coloca 1 punto en la
  banda biológica (10-100 kHz). Recomendación pre-mentor: cambiar a
  1 kHz / 30 kHz / 300 kHz (anchor iónico + bio core + transición dieléctrica).
  Decisión final pendiente OQ-006.
- **DC offset del electrodo:** 50-200 mV típicos en stainless steel en suelo.
  TIA actual sin AC coupling. Recomendación: auto-zero firmware (OQ-007).
- **Corrección no-lineal de T:** REQ-PR-001 lineal Q8.8 no captura
  Debye/Arrhenius. Decisión: punt to VPS via Z(ω, T) surface ML (OQ-008).
- **PSRR de VREF_OUT:** 0.05% precisión exportada requiere buffer dedicado
  + compensación externa. Recomendación: opción 1 con red RC en PCB (OQ-009).
- **Padring choice:** workshop slot 88-pin (vs slots menores) — confirmed.

### PDK reality (vs. SPEC original)
- ❌ Package QFN-40 → ✅ Workshop slot 88-pin padring (60 analog + 20 bidir)
- ❌ Die 2.7 mm² → ✅ Core 2051×2051 µm dentro de die 2935×2935 µm
- ❌ VDD_D = 1.8V via external LDO → ✅ 3.3V único (PDK no soporta 1.8V cells)
- ❌ Tape-out 11 sept → ✅ Final Submission TBD ~oct 2026 (post Final Chip Review 28 sept)
- ❌ "PICO onboarding 1 may" → ✅ Kick-off 8 may (Boris Murmann + Mehdi Saligane)

### Pin assignment recortes (24 → 20 digitales)
- Eliminado: `EN_LDO` (no hay LDO externo en arquitectura 3.3V único)
- Eliminado: `CS_MEM` (FeRAM externa diferida a v2)
- Eliminado: `PULSE_IN[1]` (solo EC pulse counter en v1)
- Muxed: `TAMPER` con `GPIO_SW[1]` (input mode multiplexed)

### Open Questions formales
- OQ-001 a OQ-005: del SPEC original (TIA topology, ADC feasibility, mixer
  type, bandgap precision, cocotb+Spectre flow)
- **OQ-006 (nuevo):** frecuencias IS finales
- **OQ-007 (nuevo):** cancelación DC offset
- **OQ-008 (nuevo):** T-correction on-chip vs VPS
- **OQ-009 (nuevo):** VREF_OUT buffer strategy

## 2026-04-19 (pre-split, en open-silicon-mx)

### Repository consolidation
- Moved `PICO_APPLICATION.md` and `spi_slave.v` from old `nopal-sense/` folder
  to `nopal-platform/v1-pico/`
- Deleted obsolete digital-only design folder (805 lines of obsolete content)
- Single source of truth established under `nopal-platform/v1-pico/`

## 2026-04-18 (pre-split, en open-silicon-mx)

### Strategic pivot
**De diseño digital-only a mixed-signal con espectroscopía de impedancia.**

- Razón del pivot: el diseño digital-only duplicaba capacidades del MCU
  (ESP32). El IS multi-frecuencia es una capability silicon-only que ningún
  MCU genérico puede replicar a costo de campo.
- Consecuencia: Phytophthora scoring v3 sale del chip y se queda en VPS
  (debe iterar con qPCR data).

### Documentación creada
- `SPEC_FROZEN.md` — 75+ requisitos numerados
- `ARCHITECTURE.md` — design rationale por bloque + diagramas
- `PIN_ASSIGNMENT.md` — pinout (entonces QFN-40)
- `MENTOR_BRIEFING.md` — 1-pager para mentor PICO
- `ROADMAP.md` — phases 1-8 con gates
- Python golden model: 1212 líneas, 8/8 tests pasando
- Modelo de física Randles del suelo

### Decisiones técnicas tomadas
- 14-bit ADC (vs 12 o 16): balance área-precisión para 3% IS accuracy
- ADC compartido (IS + sensores, time-multiplexed): ahorra 0.4 mm²
- Internal RC oscillator (vs crystal): no external crystal, freq ratios
  deterministic aunque absolute drift
- Simple PUF (no fuzzy extractor en v1): solo chip ID, no crypto key
- Dual clock domain (1 MHz main + 32 kHz sleep): wake timer always-on
- 12 connectivity bridges: cada feature diferida tiene puente externo

## 2026-04-10 (pre-split, en open-silicon-mx)

### Day 1
- IEEE SSCS PICO Chipathon 2026 application submitted
- Original digital-only design (now historical, see `v1-pico/PICO_APPLICATION.md`)
- Tooling installed (IIC-OSIC-TOOLS, OpenLane, cocotb, Verilator)
- First Verilog module (counter) synthesized as practice
- Tiny Tapeout chip (Demoscene SKY130, cellular automaton VGA) reached
  precheck PASS — separate repo `tt-nopal-demo`

---

## Roadmap forward

Próximos cambios mayores esperados:

- **2026-05-08** — Chipathon kick-off (Boris Murmann + Mehdi Saligane)
- **2026-05-29** — Vipul Sharma full-custom analog flow lecture (Track B)
- **2026-06-05** — Team formation deadline
- **2026-06-12** — Project Proposal Review (primera presentación formal)
- **2026-07-17** — Sim Review Top + Go/No-go (hito crítico)
- **2026-09-28** — Final Chip Review
- **~2026-10** — Final Submission GDS to Channel Partner
- **~2027-01** — Chips disponibles, bring-up
- **2027-jul** — IEEE Workshop + paper submission

Cada milestone genera entradas en este changelog.
