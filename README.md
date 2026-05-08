# Nopal-Sense

**Mixed-signal sensor hub ASIC para espectroscopía de impedancia en suelo agrícola.**
**IEEE SSCS PICO Open-Source Chipathon 2026 · Track B (Circuits for Sensors) + Track D (AI/LLM-assisted).**

---

## Qué es

Nopal-Sense es un AFE (analog front-end) en GF180MCU 180 nm que:

1. **Consolida** 5 sensores comerciales de suelo (3× humedad capacitiva + sonda EC + ADS1115 ADC) en un solo die más sondas pasivas de pines metálicos
2. **Agrega** un canal de medición que no existe en ningún producto comercial: espectroscopía de impedancia (IS) multi-frecuencia en banda 10-100 kHz para detectar actividad biológica en la rizosfera
3. **Exporta** recursos internos (referencia de precisión, clock compartido, switches de poder programables, agregador de interrupts) que mejoran el resto del nodo IoT

El objetivo es **detección de anomalías en actividad biológica de la rizosfera** — no identificación de especie — vía análisis de series de tiempo de patrones de impedancia multi-frecuencia, correlacionado con ground truth qPCR.

## Arquitectura de 3 capas

```
SILICIO (este repo)  →  ESP32 firmware  →  VPS / cloud (Zafra-AgTech)
estable años            actualizable semanal   itera diariamente
```

El chip vive en la capa de silicio. El algoritmo y la inferencia ML viven en la nube, lo que mantiene el chip simple y deja que la ciencia evolucione independiente del hardware.

## Especificaciones v1

| Parámetro | Valor |
|-----------|-------|
| Proceso | GF180MCUD 180 nm (variante D, open-source PDK) |
| Padring | Workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS) |
| Die | 2935 × 2935 µm |
| Core | 2051 × 2051 µm |
| Voltaje | 3.3V único (con I/O HV 5V/6V capable) |
| IS frecuencias | 3 fijas (decisión final pendiente OQ-006) |
| ADC | 14-bit SAR compartido con MUX 8-canal |
| Sleep | <1 µA target |
| Active | ~2 mA × 100 ms por ciclo |
| Interface host | SPI slave a ESP32 (hasta 10 MHz) |

## Estructura del repo

```
nopal-sense/
├── README.md                    Este archivo
├── CHANGELOG.md                 Historia de cambios mayores
├── LICENSE                      Apache 2.0 (requisito del Chipathon)
├── docs/
│   ├── briefing.md              Investigación científica completa + reality checks
│   ├── plan.md                  Estrategia adaptada al concurso
│   └── calendario.md            Sesión por sesión del Chipathon
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

> ⚠️ **Pendiente de update tras la separación del repo (mayo 2026):** Algunos
> archivos en `v1-pico/` aún reflejan asunciones del SPEC original (QFN-40,
> 1.8V dual). Estos se actualizan progresivamente conforme avance el chipathon.
> Ver `docs/briefing.md` §9 (Architectural Reality Checks) para la lista
> completa de inconsistencias detectadas y sus resoluciones propuestas.

## Status — mayo 2026

- ✅ Spec frozen v1.0
- ✅ Golden model 1212 líneas, 8/8 tests pasando
- ✅ 5 architectural reality checks documentados (frecuencias, DC offset, T-correction, PSRR, padring)
- ✅ Open Questions OQ-001 a OQ-009 formales
- ✅ Tracks B + D confirmed
- ⏳ **Phase 1** (May 8 – May 29 2026): tooling + tutorials + mentor matching
- ⏳ Phase 2 (Jun 2026): team formation + project proposal review (12 jun)
- ⏳ Phase 3 (Jul 2026): schematic + simulation + Go/No-go (17 jul)
- ⏳ Phase 4 (Ago-Sep 2026): layout + DRC + final submission (~Oct 2026)
- ⏳ Phase 5 (~Ene 2027+): silicon bring-up + measurement + paper (Jul 2027)

## Conexión con Zafra-AgTech

Este chip es un componente de hardware usado por [Zafra-AgTech](https://github.com/Jefemaestro33/Zafra-Agtech), una plataforma de agricultura de precisión con piloto comercial en Nextipac, Jalisco (junio 2026, 100 ha de aguacate Hass).

El chip es open-source bajo Apache 2.0 (requisito Chipathon). El algoritmo de scoring Phytophthora v3+ y el dataset de campo de Zafra **no son parte del open-source del chip** — viven en la capa VPS y son trade secret del negocio de Zafra.

## Equipo

- **Ernest Darell Zermeño Plascencia** ([@Jefemaestro33](https://github.com/Jefemaestro33)) — chip design + Zafra-AgTech founder
- **Salvador** — agronomic field operations (Zafra-AgTech, no co-founder técnico del chip)
- **Mentor PICO** — TBD post-team-formation (jun 2026), preferencia analog/mixed-signal background

## Linaje arquitectónico

Este chip extiende la línea del **2022 PICO Chipathon "Electrochemical Water Quality Monitoring" chip** (USA5, University of Tennessee) — primer chip electroquímico mixed-signal del programa. Cambios en Nopal-Sense:
- Suelo en lugar de agua
- IS multi-frecuencia con DDS programable
- Architectural exports + 12 connectivity bridges para nodo IoT real
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
