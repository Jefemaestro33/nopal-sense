# Nopal-Sense

**Mixed-signal sensor platform ASIC para AgTech vertical integration.**
**IEEE SSCS PICO Open-Source Chipathon 2026 · Track B (Circuits for Sensors) + Track D (AI/LLM-assisted).**

---

## Qué es

Nopal-Sense es un AFE consolidado en GF180MCU 180 nm diseñado como **componente central** del nodo Zafra-AgTech, **no como sensor discreto**. Tres funciones simultáneas:

1. **Consolida** 5 sensores comerciales actuales del nodo Zafra (3× humedad capacitiva + sonda EC + ADS1115 ADC + VREF + clock externo) en un solo die más sondas pasivas de pines metálicos.
2. **Agrega** una capability sin equivalente comercial: **espectroscopía de impedancia (IS) multi-frecuencia** en banda 10-100 kHz para detección de organismos hifales (hongos + oomicetos) en suelo agrícola.
3. **Exporta** infrastructure que simplifica el resto del nodo: VREF de precisión, clock distribuible a ESP32, programmable power switches, interrupt aggregator. Reduce BOM y failure modes del sistema completo.

El objetivo es **detección temprana de Phytophthora cinnamomi** (oomiceto causante de root rot en aguacate, $100M+ pérdidas anuales solo en MX) — vía análisis de series de tiempo de patrones IS multi-frecuencia, correlacionado con ground truth qPCR.

## Modelo de negocio: vertical integration

Zafra-AgTech **NO vende el chip al mercado**. Lo usa internamente como componente diferenciador del servicio AgTech (similar a cómo Apple usa M-series chips internamente). El moat real es el **dataset acumulado de IS multi-año × multi-organism × multi-region** que solo nosotros podemos generar.

Esto elimina la necesidad de qualification commercial-grade, sales channel, datasheet para clientes externos, y customer support — ahorrando ~$300-500k de NRE típico de chip startups. Ver [`docs/business_model.md`](docs/business_model.md).

## Estrategia dual-pilot

Dos pilotos complementarios que NO compiten por recursos:

| Piloto | Hardware | Goal | Período |
|--------|----------|------|---------|
| **Field Nextipac** (100 ha aguacate Hass) | Stack commercial actual (humidity, EC, ADS1115, T) | Operacional + comercial | Jun 2026+ (bridge state hasta v2 chip ready) |
| **Greenhouse research** | 10 chips chipathon × 7-10 organismos puros + qPCR | Científico + técnico | Q1-Q2 2027 |

**Migration path**: 2028+ los nodos field migran progressivamente del stack commercial al chip-based. v2 commercial reemplaza ~$50/nodo de BOM por chip $3 mature.

## Programa científico de 3 etapas

| Stage | Pregunta científica | Probabilidad | Hardware |
|-------|---------------------|--------------|----------|
| **Stage 1** | ¿Hay organismo hifal vivo o no? | **>90%** | v1 chipathon suficiente |
| **Stage 2** | ¿Hongo (quitina) u oomiceto (celulosa)? Vía firma temporal de zoosporogenesis post-wet | **65-80%** | v1 + firmware updates |
| **Stage 3** | ¿Qué especie específica? Vía ML supervised by qPCR ground truth | **30-50%** | v2 mask set + dataset multi-año |

Cada Stage tiene valor comercial **independiente** ($1-2M/año MX | $30-60M/año | $15M premium tier). El approach escalonado permite Plan B en cada nivel — si Stage 3 falla, Stage 1+2 sostienen el negocio. Ver [`docs/research_program.md`](docs/research_program.md).

## Arquitectura de 3 capas

```
SILICIO (este repo)  →  ESP32 firmware  →  VPS / cloud (Zafra-AgTech)
estable años            actualizable semanal   itera diariamente
```

El chip vive en silicio. El algoritmo y la inferencia ML viven en cloud, lo que mantiene chip simple y deja la ciencia evolucionar independiente del hardware.

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
│   ├── briefing.md              Investigación científica completa + reality checks
│   ├── plan.md                  Estrategia adaptada al concurso
│   ├── calendario.md            Sesión por sesión del Chipathon
│   ├── research_program.md      Stage 1/2/3 formal + greenhouse pilot
│   └── business_model.md        Vertical integration + Apple analogy
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
└── v2-commercial/               Roadmap producto comercial 2028+
    └── README.md
```

> ⚠️ **Pendiente de update progresivo:** Algunos archivos en `v1-pico/` aún reflejan asunciones del SPEC original (QFN-40, 1.8V dual, tape-out Sept). Estos se actualizan progresivamente conforme avance el chipathon. Ver `docs/briefing.md` §9 (Architectural Reality Checks).

## Status — mayo 2026

- ✅ Spec frozen v1.0 (con resolución pendiente de OQ-006 a OQ-009)
- ✅ Golden model 1212 líneas, 8/8 tests pasando
- ✅ 5 architectural reality checks documentados
- ✅ Open Questions OQ-001 a OQ-009 formales
- ✅ 3-stage research program formalizado
- ✅ Dual-pilot strategy definido
- ✅ Vertical integration model confirmed
- ✅ Tracks B + D confirmed
- ⏳ **Phase 1** (May 8 – May 29 2026): tooling + tutorials + mentor matching
- ⏳ Phase 2 (Jun 2026): team formation + project proposal review (12 jun)
- ⏳ Phase 3 (Jul 2026): schematic + simulation + Go/No-go (17 jul)
- ⏳ Phase 4 (Ago-Sep 2026): layout + DRC + final submission (~Oct 2026)
- ⏳ Phase 5 (~Ene 2027+): silicon bring-up + greenhouse pilot + paper (Jul 2027)

## Conexión con Zafra-AgTech

Este chip es un componente de hardware usado por [Zafra-AgTech](https://github.com/Jefemaestro33/Zafra-Agtech), una plataforma de agricultura de precisión con piloto comercial en Nextipac, Jalisco (junio 2026, 100 ha de aguacate Hass).

El chip es open-source bajo Apache 2.0 (requisito Chipathon). El algoritmo de scoring Phytophthora v3+ y el dataset de campo de Zafra **no son parte del open-source del chip** — viven en la capa VPS y son trade secret del negocio de Zafra.

## Equipo

- **Ernest Darell Zermeño Plascencia** ([@Jefemaestro33](https://github.com/Jefemaestro33)) — chip design + Zafra-AgTech founder
- **Salvador** — agronomic field operations (Zafra-AgTech, no co-founder técnico del chip)
- **Mentor PICO** — TBD post-team-formation (jun 2026), preferencia analog/mixed-signal con experiencia en biosensors / electrochemical impedance

## Linaje arquitectónico

Este chip extiende la línea del **2022 PICO Chipathon "Electrochemical Water Quality Monitoring" chip** (USA5, University of Tennessee) — primer chip electroquímico mixed-signal del programa. Cambios en Nopal-Sense:
- Suelo en lugar de agua
- IS multi-frecuencia con DDS programable
- Architectural exports + 12 connectivity bridges para nodo IoT real
- Vertical integration model (no se vende el chip)
- 3-stage research program disciplined
- **Primer chip mexicano del programa PICO**

## Repos relacionados

| Repo | Qué es | Visibilidad |
|------|--------|-------------|
| [nopal-sense](https://github.com/Jefemaestro33/nopal-sense) | Este repo (chipathon project) | Público (Apache 2.0) |
| [tt-nopal-demo](https://github.com/Jefemaestro33/tt-nopal-demo) | Tiny Tapeout chip de práctica (separado) | Público |
| [Zafra-Agtech](https://github.com/Jefemaestro33/Zafra-Agtech) | Sistema AgTech que el chip habilita | Privado |
| [mx-silicon-research](https://github.com/Jefemaestro33/mx-silicon-research) | Research personal de semiconductores en MX | Privado |

## Licencia

- **Verilog y especificaciones técnicas:** Apache 2.0 (requisito PICO Chipathon)
- **Documentación:** CC BY-SA 4.0
- **Algoritmos Phytophthora + dataset de campo:** trade secret de Zafra-AgTech, NO parte de este repo

## Acknowledgments

Diseñado con mentorship del programa **IEEE SSCS PICO Open-Source Chipathon 2026** (sponsor: The OpenROAD Initiative). Track leads: Camilo Velez + Vipul Sharma (B), Mehdi Saligane + Saptarshi Ghosh + Luighi (D). PDK: GF180MCUD (Google + GlobalFoundries open-source). Tooling: IIC-OSIC-TOOLS Docker (Harald Pretl, JKU Linz).

RTL co-diseñado con Claude AI (Anthropic) — Track D submission angle.
