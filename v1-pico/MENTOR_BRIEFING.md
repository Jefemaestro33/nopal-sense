# Mentor Briefing — Nopal-Sense v1

**For:** PICO Chipathon 2026 mentor assignment
**From:** Ernest Darell Zermeño Plascencia — [@Jefemaestro33](https://github.com/Jefemaestro33)
**Reading time:** ~5 minutes

---

## TL;DR

Diseñando **mixed-signal sensor platform ASIC** que reemplaza múltiples sensores comerciales (capacitive humidity + EC + ADC + VREF + clock) y agrega **multi-freq impedance spectroscopy** (10-100 kHz) para detección de organismos hifales en suelo agrícola. NO discrete IS sensor — es plataforma consolidada.

**Vertical integration model**: el operador del chip (mi startup AgTech, Zafra-AgTech, con piloto operacional en aguacate en Jalisco, México) usa el chip internamente, no lo vende al mercado. Detalles operacionales en repo privado del operador.

**Greenhouse pilot Q1-Q2 2027** valida la apuesta científica con organismos puros + qPCR ground truth en condiciones controladas.

**Programa científico de 3 etapas escalonadas** (Stage 1 >90%, Stage 2 65-80%, Stage 3 30-50% probabilidades). Cada Stage tiene valor independiente — Plan B en cada nivel.

**Background**: Software/data engineering deep, **first mixed-signal chip**. Tiny Tapeout digital previo (SKY130, precheck PASS).

**Necesito mentor con analog/mixed-signal background, idealmente lock-in detection / electrochemical impedance / biosensors.**

---

## El chip en una mirada

| Parámetro | Valor |
|-----------|-------|
| Proceso | GF180MCUD 180nm (open-source variant) |
| Padring | Workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS) |
| Die | 2935 × 2935 µm |
| Core | 2051 × 2051 µm |
| Voltaje | **3.3V único** (con I/O HV 5V/6V capable) |
| Flagship capability | IS multi-freq **10 kHz / 30 kHz / 100 kHz** (bio-band specialist; OQ-006 = B resuelto) |
| Consolidates | 5 sensores commerciales del nodo Zafra actual |
| Exports | VREF precision, clock distrib, programmable power switches, IRQ aggregator |
| Target power | <1 µA sleep, <2 mA active |
| Interface host | SPI slave a ESP32 (hasta 10 MHz) |
| Tape-out | TBD ~Sept 2026 (post Final Chip Review 28 ago) |

Full spec: [`SPEC_FROZEN.md`](./SPEC_FROZEN.md) — 75+ requirements
Architecture: [`ARCHITECTURE.md`](./ARCHITECTURE.md)
Pin assignment: [`PIN_ASSIGNMENT.md`](./PIN_ASSIGNMENT.md)
Pre-mentor research program: [`../docs/research_program.md`](../docs/research_program.md)

---

## El contexto que importa

### Operational context

Soy founder de un AgTech startup (Zafra-AgTech) con piloto operacional en aguacate Hass en Jalisco, México. Stack actual del nodo usa sensor commercial conocido (capacitive humidity, EC, ADC externo, etc.). Funciona, pero **NO tiene impedance spectroscopy** — y ese es exactamente el canal que necesitamos para detectar Phytophthora cinnamomi (oomiceto causante de root rot, problema económico significativo en MX avocado industry).

El chipathon chip Nopal-Sense **agrega esa capability** (IS) Y **consolida** la stack del nodo en un solo die. Detalles operacionales del operador (revenue, customers, deployment economics) están en repo privado del operador, no en este repo.

### Por qué custom chip vs AD5940

AD5940 (Analog Devices) hace IS commercial. ¿Por qué no lo usamos?

- AD5940 limited a 4 frecuencias preset, bandwidth 200 kHz, sin DDS programable
- AD5940 no maneja DC offset 50-280 mV típico en suelo crudo (sin AC coupling externo)
- AD5940 ~1-3 mA active vs nuestro target <2 mA
- AD5940 NO consolidates humedad cap + EC + ADC — son chips separados
- AD5940 NO exports VREF + clock + power switches al resto del nodo

Nuestro chip custom enables ambos:
1. Stage 2 science (zoosporogenesis temporal detection en banda específica)
2. BOM consolidation que AD5940 no puede dar

### Vertical integration (no vendemos el chip)

A diferencia de chip startup tradicional, el operador (Zafra-AgTech) NO vende Nopal-Sense al mercado. Lo usa internamente como diferenciador del servicio AgTech (similar a Apple con M-series). Esto elimina mucho del NRE típico (sales, datasheet, customer support, commercial qualification) — pero los detalles operacionales del modelo de negocio están en el repo privado del operador.

---

## El programa científico (3 etapas escalonadas)

El chip va a **greenhouse research validation Q1-Q2 2027**, NO a field deployment directo. Approach escalonado:

| Stage | Pregunta | Probabilidad | Lo que valida |
|-------|----------|--------------|---------------|
| **Stage 1** | ¿Hay organismo hifal vivo o no? (vs sterile soil) | **>90%** | β-dispersion en banda 10-100 kHz |
| **Stage 2** | ¿Hongo (quitina) u oomiceto (celulosa)? | **65-80%** | Firma temporal de zoosporogenesis post-wet event |
| **Stage 3** | ¿Especie específica? (P. cinnamomi vs P. infestans) | **30-50%** | ML supervised by qPCR (requiere v2 chip + dataset multi-año) |

Cada Stage tiene valor independiente. **Aún si Stage 3 nunca funciona, Stage 1+2 sostienen la utilidad del chip.** Esa es la disciplina de la apuesta.

Mecanismo físico clave: oomicetos tienen **paredes celulares de celulosa** (vs quitina en hongos verdaderos) y producen **zoosporas móviles** después de wet events. Eso da firma temporal distinguible aunque steady-state fingerprinting falle.

Ver [`../docs/research_program.md`](../docs/research_program.md) para framework científico completo.

---

## Status (2026-05-08, kick-off day)

### ✅ Complete
- System architecture + 3-layer design (silicon / firmware / VPS)
- Frozen specification with 75+ numbered requirements
- Register map (32 × 16-bit)
- Pin assignment (workshop slot 88-pin alignment)
- Block-level area estimates
- Power budget per block + per cycle
- Python golden model (1212 lines, 8/8 tests passing)
- Operational backing via Zafra-AgTech (details in private repo)
- 3-stage research program formalizado
- Vertical integration model confirmed

### ⏳ In progress
- Cocotb testbench infrastructure + test vector generation
- Greenhouse pilot logistics (cultures, qPCR partner, infrastructure)
- v1 priority labeling (P1/P2/P3 modular spine)

### ❌ Pending (need mentor help)
- Analog block design: TIA topology, mixer I/Q, DAC, bandgap reference
- DC offset cancellation strategy (auto-zero firmware vs hardware AC coupling — OQ-007)
- VREF buffer PSRR strategy (OQ-009)
- Mixed-signal verification flow (Spectre AMS or equivalent)
- Layout strategy (analog/digital separation, guard rings, matching)
- Process corner analysis priorities

---

## Track Selection

- **Primary:** Track B — Circuits for Sensors (because IS is electrochemical sensor + mixed-signal)
- **Secondary:** Track D — AI/LLM-assisted Circuits (entire RTL co-designed with Claude AI)

---

## Specific Questions for Mentor

### Architecture & Topology
1. Para TIA en 180nm con DC offset 50-280 mV en electrodos de suelo: ¿shunt-feedback con auto-zero chopping, o instrumentation amp con AC coupling capacitive? Tradeoffs?
2. Mixer I/Q para lock-in detection: switching demodulator (Gilbert) vs analog multiplier — cuál tiene mejor noise floor para nuestro dynamic range (Z 100Ω – 30kΩ a bio-band 10-100 kHz)?
3. Para 3% IS magnitude accuracy across DR: ¿14-bit SAR ADC alcanza, o necesito ΔΣ?
4. Bandgap reference: ¿qué accuracy mínima para 0.05% PSRR del VREF_OUT exportado (OQ-009)?

### Verification
5. ¿Recomendado cocotb + Spectre AMS flow específico? Setup público disponible que pueda copiar?
6. Para mixed-signal 180nm: ¿100, 500, 1000 Monte Carlo runs de sign-off?
7. Process corners priority: ¿FF/SS dominan o también FS/SF crítico para mi diseño?

### Risk Management & Modular Strategy
8. Mi v1 tiene 6+ analog blocks compartiendo bandgap + supply. ¿Estructurar en "modular spine" con priority labels (P1/P2/P3) reduce risk vs monolithic — o introduce más interface bugs?
9. ¿Qué bloque tiene mayor probabilidad de fallar tape-out así como está scoped? (TIA con auto-range? Mixer? Multi-channel ADC compartido?)
10. ¿Vale la pena scope down a 2 frecuencias IS y agregar la 3ra en v1.1, o las 3 son rentables en v1?

### Process specifics
11. GF180MCUD analog cells — ¿hay reference designs específicos del PDK que estudie primero (especialmente para TIA y bandgap)?
12. ¿GF180MCUD PDK incluye verification IP razonable, o presupuesto tiempo para construir mío propio?

---

## What I Bring

- **Domain expertise**: AgTech operational + bioinformatics background
- **Real sensor data background**: prior commercial sensor deployments validate operational use case (specifics in operator's private repo)
- **Python golden model**: 1212 lines, bit-exact spec, 8/8 unit tests passing
- **Software discipline**: Backend, dashboard, Phytophthora scoring v3 ya en producción
- **Documentation discipline**: SPEC_FROZEN, ARCHITECTURE, ROADMAP, research_program, business_model — todos versionados
- **Time commitment**: Full-time dedicación junio-octubre 2026; part-time mayo + post-tape-out
- **Prior silicon experience**: Tiny Tapeout digital chip (SKY130, GDS generated, precheck PASS — separate repo `tt-nopal-demo`)

---

## What I Need from Mentor

1. **Weekly 1-on-1 calls** (1 hour, video + screen share preferido)
2. **Review de analog block designs** antes de layout commit
3. **Mixed-signal verification guidance** (especialmente corner analysis methodology)
4. **Reality check on scope** — willing to cut features if necesario para tape-out a tiempo
5. **Review del tape-out submission package** pre-Sept 28 Final Chip Review

Trabajo asíncrono outside weekly calls. Disciplinado preparando preguntas específicas pre-meeting.

---

## Logistics

- **Time zone:** Guadalajara, Mexico (UTC-6/-5 DST)
- **Availability:** Flexible, match mentor's schedule
- **Preferred cadence:** Weekly 1h call + async messaging (Discord chipathon channel / GitHub / email)
- **Language:** English or Spanish (native)
- **Contact:** via Discord chipathon o GitHub [@Jefemaestro33](https://github.com/Jefemaestro33)

---

## Backup Plans

Si assigned mentor es digital-only:
- Scope down a simpler sensor hub (drop full IS to v2)
- Partner con otro team's mentor para analog reviews
- Use PDK forums + GF180MCUD community para analog questions

Pero **prefiero preservar IS como flagship** — es lo que valida la apuesta científica del operador y el moat real del producto.

---

**One-line ask:** *Please assign a mentor con tape-out experience en mixed-signal con on-chip ADCs y analog front-ends, idealmente con biosensing o electrochemical impedance background.*
