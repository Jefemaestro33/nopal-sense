# Changelog

Historial de cambios mayores del proyecto Nopal-Sense.

## 2026-05-08 — Strategic clarifications pre-kickoff

Esta entrada documenta clarificaciones estratégicas mayores hechas durante deep-thinking session pre-kickoff. Ningún cambio de SPEC o RTL — son framings que afectan cómo se comunica y prioriza el proyecto.

### Vertical integration model confirmed
- **Zafra-AgTech NO vende el chip** al mercado abierto. Lo usa internamente
  como componente diferenciador del servicio AgTech (analogous a Apple con
  M-series chips).
- Esto elimina ~$300-500k de NRE típico de chip startups: no sales channel,
  no datasheet para clientes, no qualification commercial-grade, no customer
  support de chips.
- Implicación: el chip es CapEx para Zafra, no producto comercial. Cost
  trajectory: $250/chip MPW (2027) → $3/chip mask set mature (2030+).
- Ver `docs/business_model.md` (creado en este sprint).

### Chip como plataforma, no sensor discreto
- Re-énfasis: el chip cumple **3 funciones simultáneas**, no solo IS:
  (1) **Consolida** 5 sensores commerciales actuales del nodo Zafra
  (2) **Agrega** capability nueva (IS multi-freq)
  (3) **Exporta** infrastructure (VREF, clock, power switches, IRQ aggregator)
- Comparación BOM: $96/nodo commercial stack → $58/nodo chip-based mature
  ($38/nodo savings × 10k+ nodos = $380k+/año puro consolidation savings)
- Pitch a mentor cambia de "IS sensor IC" a "consolidated AFE platform".

### Programa científico de 3 etapas formalizado
Cada Stage es **independientemente valiosa** y proporciona Plan B si las
siguientes fallan.

| Stage | Pregunta | Probabilidad |
|-------|----------|--------------|
| Stage 1 | ¿Hay organismo hifal? | >90% |
| Stage 2 | ¿Hongo (quitina) u oomiceto (celulosa)? Vía firma temporal de zoosporogenesis | 65-80% |
| Stage 3 | ¿Especie específica? Vía ML qPCR-supervised | 30-50% |

- Mecanismo físico clave para Stage 2: oomicetos liberan zoosporas móviles
  post-wet event → spike detectable en Z(ω) que hongos no producen.
- Stage 1 alone = $1-2M/año MX market (organic farms + soil health).
- Stage 1+2 = $30-60M/año MX (avocado + citrus Phytophthora detection).
- Stage 3 = $15M premium tier (species-specific treatment selection).
- Ver `docs/research_program.md` (creado en este sprint).

### Dual-pilot strategy
Dos pilotos paralelos que NO compiten por recursos:
- **Field pilot Nextipac** (jun 2026, 100 ha aguacate Hass): usa stack
  commercial actual (humidity, EC, ADS1115, T) — valida operacional y
  comercial. Bridge state hasta v2 chip ready.
- **Greenhouse pilot** (Q1-Q2 2027): usa 10 chips chipathon × 7-10
  organismos puros + qPCR ground truth — valida científico y técnico.
- Migration: 2028+ field nodes migran progressivamente a chip-based.

### v1 priority strategy: modular spine
Para reducir risk de bring-up, los 75+ requisitos del SPEC se etiquetarán
con priority labels:
- **P1 (must-work bring-up gate)**: IS path + ADC + SPI + VREF + bandgap
- **P2 (firmware-debugged si borderline)**: humidity readout, EC, MUX,
  auto-zero
- **P3 (deferable a v1.1)**: power switches, clock export, IRQ aggregator

Si bring-up reveals bugs en P2/P3, IS standalone permite greenhouse pilot
y paper publishable.

### Oomycete-specific science framing
- Phytophthora **NO es hongo**. Es oomiceto (reino Stramenopiles).
- Pared celular de **celulosa** (no quitina): firma dieléctrica diferenciable
  en banda 30-100 kHz.
- Hifas **coenocíticas** (sin septos): conducción intracelular continua.
- **Sin ergosterol** en membranas (usa fucosterol): β-dispersion shift.
- **Zoosporas móviles** post-wet event: smoking gun temporal para Stage 2.

### Documentación creada en este sprint
- `docs/research_program.md` — 3-stage formal framework
- `docs/business_model.md` — vertical integration explained
- `README.md` — reescrito con platform framing + 3-stage + dual-pilot
- `v1-pico/MENTOR_BRIEFING.md` — reescrito con mature pitch para mentor
  matching de hoy

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
