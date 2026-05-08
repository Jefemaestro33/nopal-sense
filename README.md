# Nopal-Sense

**Mixed-signal sensor platform ASIC para AgTech vertical integration.**
**IEEE SSCS PICO Open-Source Chipathon 2026 · Track B (Circuits for Sensors) + Track D (AI/LLM-assisted).**

> **Scope of this repo**: chip design and high-level science framework only. Detailed business model, customer specifics, deployment economics, and proprietary algorithms (Phytophthora detection v3+, field datasets, revenue model) live in the private [Zafra-Agtech](https://github.com/Jefemaestro33/Zafra-Agtech) repo. This repo is sufficient for chipathon technical evaluation and chip-related contributions — not for business due diligence or competitive analysis.

---

## Qué es

Nopal-Sense es un AFE consolidado en GF180MCU 180 nm diseñado como **componente central** del nodo Zafra-AgTech, **no como sensor discreto**. Tres funciones simultáneas:

1. **Consolida** múltiples sensores comerciales del nodo (capacitive humidity probes, EC probe, ADC externo, voltage reference, clock distribution) en un solo die más sondas pasivas de pines metálicos.
2. **Agrega** una capability sin equivalente comercial: **espectroscopía de impedancia (IS) multi-frecuencia** en banda 10-100 kHz para detección de organismos hifales (hongos + oomicetos) en suelo agrícola.
3. **Exporta** infrastructure que simplifica el resto del nodo: VREF de precisión, clock distribuible a ESP32, programmable power switches, interrupt aggregator.

El objetivo es **detección temprana de Phytophthora cinnamomi** (oomiceto causante de root rot en aguacate) — vía análisis de series de tiempo de patrones IS multi-frecuencia, correlacionado con ground truth qPCR.

## Modelo: vertical integration

El operador del chip (Zafra-AgTech) **NO vende el chip al mercado abierto**. Lo usa internamente como componente diferenciador del servicio AgTech (analogía: Apple con M-series chips). Esto elimina sales channel, datasheet para clientes externos, qualification commercial-grade, y customer support — reduce significativamente NRE típico de chip startups.

Detalles operacionales del operador (revenue, customers, deployment economics, mask set funding) viven en el repo privado de Zafra-AgTech, NO en este repo.

## Programa científico de 3 etapas

| Stage | Pregunta científica | Probabilidad | Hardware |
|-------|---------------------|--------------|----------|
| **Stage 1** | ¿Hay organismo hifal vivo o no? | **>90%** | v1 chipathon suficiente |
| **Stage 2** | ¿Hongo (quitina) u oomiceto (celulosa)? Vía firma temporal de zoosporogenesis post-wet | **65-80%** | v1 + firmware updates |
| **Stage 3** | ¿Qué especie específica? Vía ML supervised by qPCR ground truth | **30-50%** | v2 mask set + dataset multi-año |

Cada Stage tiene valor científico/operacional **independiente**. El approach escalonado permite Plan B en cada nivel — si Stage 3 falla, Stage 1+2 sostienen el negocio. Ver [`docs/research_program.md`](docs/research_program.md).

## Validación: greenhouse pilot (Q1-Q2 2027)

El chip v1 chipathon será validado en **greenhouse pilot controlado** (Q1-Q2 2027) con organismos puros + qPCR ground truth, NO field deployment directo. Es el approach disciplinado para validar la apuesta científica antes de scale.

Detalles operacionales del greenhouse pilot (logística, partners, infrastructure budget, organism specifics) son operacionales y viven en el repo privado del operador.

## Arquitectura de 3 capas

```
SILICIO (este repo)  →  ESP32 firmware  →  VPS / cloud (operator-side)
estable años            actualizable semanal   itera diariamente
```

El chip vive en silicio. El algoritmo y la inferencia ML viven en cloud — estructura que mantiene chip simple y deja la ciencia evolucionar independiente del hardware.

## Especificaciones v1

| Parámetro | Valor |
|-----------|-------|
| Proceso | GF180MCUD 180 nm (variante D, open-source PDK) |
| Padring | Workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS) |
| Die | 2935 × 2935 µm |
| Core | 2051 × 2051 µm |
| Voltaje | 3.3V único (con I/O HV 5V/6V capable) |
| IS frecuencias | 3 fijas (recomendación pre-mentor: 1k/30k/300k Hz, decisión final OQ-006) |
| ADC | 14-bit SAR compartido con MUX 8-canal |
| Sleep | <1 µA target |
| Active | ~2 mA × 100 ms por ciclo |
| Interface host | SPI slave a ESP32 (hasta 10 MHz) |

**v1 priority strategy (modular spine)** — para reducir risk de bring-up:
- **P1 (must-work gate)**: IS path completo + ADC + SPI + VREF + bandgap
- **P2 (debugged en firmware si borderline)**: humidity readout, EC, MUX, auto-zero
- **P3 (deferable a v1.1)**: power switches, clock export, IRQ aggregator

Si bring-up reveals bugs en P2/P3 blocks, IS sigue funcionando standalone → greenhouse pilot puede correr → paper publishable.

## Estructura del repo

```
nopal-sense/
├── README.md                    Este archivo
├── CHANGELOG.md                 Historia de cambios mayores
├── LICENSE                      Apache 2.0 (requisito del Chipathon)
├── docs/
│   ├── briefing.md              Investigación científica
│   ├── plan.md                  Estrategia adaptada al concurso
│   ├── calendario.md            Sesión por sesión del Chipathon
│   └── research_program.md      Stage 1/2/3 framework científico
├── v1-pico/                     Diseño para PICO Chipathon 2026
│   ├── README.md                Overview técnico v1
│   ├── SPEC_FROZEN.md           Especificación formal (75+ REQ)
│   ├── ARCHITECTURE.md          Design rationale por bloque
│   ├── PIN_ASSIGNMENT.md        Asignación física al workshop slot
│   ├── MENTOR_BRIEFING.md       1-pager para mentor PICO
│   ├── ROADMAP.md               Phases 1-8 ejecutables
│   ├── PICO_APPLICATION.md      Aplicación oficial original (histórica)
│   ├── rtl/
│   │   └── spi_slave.v          Verilog (en desarrollo)
│   └── sim/
│       └── golden_model.py      Modelo Python bit-exact (1212 líneas, 8/8 tests)
└── v2-commercial/               Roadmap producto comercial
    └── README.md
```

> ⚠️ **Pendiente de update progresivo:** Algunos archivos en `v1-pico/` aún reflejan asunciones del SPEC original (QFN-40, 1.8V dual, tape-out Sept). Estos se actualizan progresivamente conforme avance el chipathon. Ver `docs/briefing.md` §9 (Architectural Reality Checks).

## Status — mayo 2026

- ✅ Spec frozen v1.0 (con resolución pendiente de OQ-006 a OQ-009)
- ✅ Golden model 1212 líneas, 8/8 tests pasando
- ✅ 5 architectural reality checks documentados
- ✅ Open Questions OQ-001 a OQ-009 formales
- ✅ 3-stage research program formalizado
- ✅ Vertical integration model confirmed
- ✅ Tracks B + D confirmed
- ⏳ **Phase 1** (May 8 – May 29 2026): tooling + tutorials + mentor matching
- ⏳ Phase 2 (Jun 2026): team formation + project proposal review (12 jun)
- ⏳ Phase 3 (Jul 2026): schematic + simulation + Go/No-go (17 jul)
- ⏳ Phase 4 (Ago-Sep 2026): layout + DRC + final submission (~Oct 2026)
- ⏳ Phase 5 (~Ene 2027+): silicon bring-up + greenhouse pilot + paper (Jul 2027)

## Operator: Zafra-AgTech

This chip is a hardware component of [Zafra-AgTech](https://github.com/Jefemaestro33/Zafra-Agtech), a Mexican precision agriculture platform. Zafra-AgTech operates the chip internally as part of its AgTech service — it is not sold separately.

**Business operations, customer details, revenue model, deployment economics, and the Phytophthora detection algorithm (v3+) are proprietary and live in the private Zafra-Agtech repo, NOT in this repo.** This repo is self-contained for chip technical evaluation only.

Apache 2.0 covers chip design and specs. Field algorithms, datasets, and operational details are Zafra-AgTech trade secrets.

## Equipo (chip-side)

- **Ernest Darell Zermeño Plascencia** ([@Jefemaestro33](https://github.com/Jefemaestro33)) — chip design + Zafra-AgTech founder
- **Mentor PICO** — TBD post-team-formation (jun 2026), preferencia analog/mixed-signal con experiencia en biosensors / electrochemical impedance

## Linaje arquitectónico

Este chip extiende la línea del **2022 PICO Chipathon "Electrochemical Water Quality Monitoring" chip** (USA5, University of Tennessee) — primer chip electroquímico mixed-signal del programa. Cambios en Nopal-Sense:
- Suelo en lugar de agua
- IS multi-frecuencia con DDS programable
- Architectural exports + connectivity bridges para nodo IoT real
- Vertical integration model
- 3-stage research program disciplined
- **Primer chip mexicano del programa PICO**

## Repos relacionados

| Repo | Qué es | Visibilidad |
|------|--------|-------------|
| [nopal-sense](https://github.com/Jefemaestro33/nopal-sense) | Este repo (chipathon project) | Público (Apache 2.0) |
| [tt-nopal-demo](https://github.com/Jefemaestro33/tt-nopal-demo) | Tiny Tapeout chip de práctica (separado) | Público |
| [Zafra-Agtech](https://github.com/Jefemaestro33/Zafra-Agtech) | Sistema AgTech que opera este chip + business + algoritmos | Privado |
| [mx-silicon-research](https://github.com/Jefemaestro33/mx-silicon-research) | Research personal de semiconductores en MX | Privado |

## Licencia

- **Verilog y especificaciones técnicas:** Apache 2.0 (requisito PICO Chipathon)
- **Documentación:** CC BY-SA 4.0
- **Algoritmos Phytophthora + dataset de campo + business operations:** trade secret de Zafra-AgTech, NO parte de este repo

## Acknowledgments

Diseñado con mentorship del programa **IEEE SSCS PICO Open-Source Chipathon 2026** (sponsor: The OpenROAD Initiative). Track leads: Camilo Velez + Vipul Sharma (B), Mehdi Saligane + Saptarshi Ghosh + Luighi (D). PDK: GF180MCUD (Google + GlobalFoundries open-source). Tooling: IIC-OSIC-TOOLS Docker (Harald Pretl, JKU Linz).

RTL co-diseñado con Claude AI (Anthropic) — Track D submission angle.
