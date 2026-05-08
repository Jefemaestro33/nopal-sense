# Programa de Investigación Científica — Nopal-Sense

**Versión:** 1.1 (2026-05-08, post defensive-trim)
**Status:** Active framework
**Owner:** Ernest Darell Zermeño Plascencia

> **Scope**: Este documento describe el **framework científico público** del proyecto Nopal-Sense — qué preguntas científicas el chip habilita y a qué probabilidad. Los detalles operacionales del greenhouse pilot (logística, organisms específicos, protocolos detallados, infrastructure budget, market projections) son parte del business plan operacional de Zafra-AgTech y NO están en este repo público.

Este documento formaliza el **programa de investigación escalonado** que el chip Nopal-Sense habilita. Es la **apuesta científica** del proyecto: qué preguntas científicas intentamos responder, en qué orden, con qué probabilidad de éxito.

El approach es **escalonado** (sequential de-risking). Cada etapa:
- Es independientemente valiosa
- Genera el dataset necesario para la siguiente
- Reduce el riesgo de las siguientes
- Permite parar elegantemente si una falla, sin perder lo previo

---

## 1. Las 3 etapas

### Stage 1 — Detectar presencia de organismo hifal vivo

**Pregunta científica**: ¿Puede multi-frequency IS distinguir suelo con masa hifal significativa (hongos + oomicetos juntos) vs suelo sin actividad hifal?

**Probabilidad de éxito**: **>90%**

**Mecanismo físico**: Hongos y oomicetos comparten propiedades macro detectables aunque sean reinos distintos:

| Característica común | Manifestación en IS |
|---------------------|---------------------|
| Morfología hifal (5-50 µm) | Redes anisotrópicas → conducción direccional |
| Membranas celulares grandes | Capacitancia bulk en banda β-dispersion (10-100 kHz) |
| Volumen >> bacterias | β-dispersion a frecuencias más bajas |
| Polisacáridos extracelulares | Cambio en conductividad iónica intersticial |
| Metabolismo activo | pH local alterado |
| Biofilms en raíces | Interfaces dieléctricas |

**Frecuencias relevantes** (recomendación pre-mentor, OQ-006): 1k Hz (anchor iónico/agua), 30k Hz (bio core), 300k Hz (transición dieléctrica/normalización).

**Hardware suficiente**: v1 chipathon con las 3 frecuencias actuales. No requiere DDS programable wide-range.

**Evidencia previa**: Literatura sólida desde 1990s validando IS para soil biological activity discrimination (Wageningen UR, ETH, UC Davis publications).

**Approach experimental** (high level): pure cultures controladas representando organismos hifales vs controles (sterile + no-hyphal). IS continuo + qPCR ground truth. Análisis: clustering en feature space spectral.

---

### Stage 2 — Distinguir hongo vs oomiceto

**Pregunta científica**: Dado que detectamos vida hifal, ¿podemos diferenciar si es fungal (paredes de quitina) u oomicete (paredes de celulosa)?

**Probabilidad de éxito**: **65-80%**

**Las diferencias físicas relevantes**:

| Propiedad | Hongos verdaderos | Oomicetos | Implicación IS |
|-----------|-------------------|-----------|----------------|
| Pared celular polímero | Quitina | **Celulosa** | Más OH → más H-bonding → loss tangent diferente en banda específica |
| Espesor pared | 100-200 nm | 50-100 nm | Capacitancia de pared diferente |
| Septación hifas | Septate | **Coenocítica** | Conducción intracelular continua vs segmentada |
| Esteroles membrana | Ergosterol | **Fucosterol** | β-dispersion frequency shift ~5-15% |
| Producción zoosporas | NO | **Sí** (post-wet) | **Smoking gun temporal único** |

**El insight clave**: Stage 2 puede ser difícil en steady-state, pero es **mucho más fácil en transient detection (event-driven)**.

**Por qué la zoosporogenesis es la smoking gun temporal**:

```
Después de lluvia fuerte (suelo wet):

Suelo con hongos:                          Suelo con oomicetos:
                                           
│Z│ vs tiempo                              │Z│ vs tiempo
 │                                          │   ╲
 │  ╲___                                    │    ╲___ ← spike de
 │  ╲   ╲___ ← descenso suave              │   ╲    │     zoosporogenesis
 │  ╲       ╲___                            │    ╲   │
 │  ╲           ╲___                        │     ╲  │
 └──────────────                            └──────────────
  0h    24h   48h   72h                      0h    24h   48h   72h
```

Oomicetos liberan zoosporas móviles después de wet events. Hongos NO. Esa redistribución de biomasa intracelular → masa móvil → cambio temporal súbito en IS = **firma de evento detectable**.

**Approach dual**:
1. **Steady-state spectral classification** (ML model trained on cellulose vs chitin signatures): ~50-60% probability standalone
2. **Event-driven temporal detection** (zoospore release post-rain): ~75-85% probability standalone
- Combinando ambos: ~80% probability total

**Hardware**: v1 chip + firmware updates (event-trigger mode + high temporal resolution post-wet). NO requiere v2 hardware necesariamente.

**Approach experimental** (high level): cultures puros representativos de oomicetos target + control hongos + control bacterias. Wet-dry cycling para inducir eventos detectables. qPCR ground truth.

---

### Stage 3 — Identificar especie específica

**Pregunta científica**: Dado que detectamos un oomiceto, ¿podemos identificar la especie específica?

**Probabilidad de éxito**: **30-50%** (predicción útil supervised by qPCR)
**Probabilidad de fingerprinting puro**: **<10%** (steady-state spectral ID)

**Por qué es genuinamente difícil**:

| Variable | Magnitud típica de variación |
|----------|----------------------------|
| Diferencia inter-especie en hyphal diameter | 10-20% |
| Variación intra-especie (cepas) | 15-30% |
| Variación por edad cultivo | 20-40% |
| Variación por nutrientes | 30-50% |
| Variación por temperatura | 20-30% |

El signal de especie está **sepultado en ruido biológico**. Esto es por qué qPCR domina species ID en biología — busca firmas moleculares (DNA), no fenotípicas.

**La salida realista: ML supervised by qPCR ground truth**

No haces species ID **directa** vía IS. Haces:
1. IS captura un pattern complejo multivariable
2. qPCR te dice "load = X" en muestras adyacentes
3. ML model aprende correlación entre IS pattern y qPCR result
4. Después de N=10,000+ pares (IS, qPCR), el modelo predice qPCR result desde IS solo

**Esto NO es species fingerprinting verdadero. Es estimación supervisada.** Pero "predicción útil" es lo que necesita el operacional, no fingerprinting puro.

**Hardware**: v2 mask set con expanded frequency support, lower noise floor, programmable integration time. Requiere dataset acumulado multi-año.

---

## 2. Cómo cada etapa mapea a generación de chip

```
Stage 1 (presencia)        →  v1 chipathon (3 freq, basic)         ✅ CURRENT SPEC
Stage 2 (kingdom)          →  v1 firmware update + maybe v1.1 MPW   ✅ NO HW CHANGES (firmware)
Stage 2 advanced (events)  →  v1.1 MPW con event-trigger mode       🟡 firmware-only
Stage 3 (species)          →  v2 mask set (expanded freqs, lower noise) 🔴 NUEVO HW

Año:         2027         2028           2029-2030       2031+
Hardware:    v1 chipathon v1.1 MPW       v2 MPW          v2 mask set
Validates:   Stage 1      Stage 2 ev.    Stage 3 init    Stage 3 mature
```

**Punto crítico**: el chip v1 chipathon **es suficiente para Stage 1 + parte de Stage 2** (la parte event-driven). El v2 viene cuando ya hay datos para justificarlo.

---

## 3. Math del de-risking sequential

Las probabilidades se **multiplican** si fallas, pero el valor científico/comercial se **suma**:

| Si funciona | Probabilidad | Producto/capability |
|-------------|--------------|---------------------|
| Solo Stage 1 | 0.90 | Soil biological activity monitoring |
| Stage 1 + 2 | 0.68 | Phytophthora threat detection |
| Stage 1 + 2 + 3 | 0.27 | Species-aware treatment selection |

**Probabilidad de que NADA funcione**: ~10%. Es decir, **90% probabilidad de que el chip valida algo útil en al menos un nivel.**

Cada nivel tiene valor independiente — Plan B en cada Stage. Si Stage 3 nunca funciona, Stage 1+2 sostienen la utilidad del chip y del programa científico.

---

## 4. Por qué es necesario chip custom (vs commercial)

Stage 1 puede hacerse técnicamente con AD5940 commercial. Pero Stage 2 + Stage 3 requieren capabilities que ningún chip comercial provee:

| Limitación AD5940 | Por qué bloquea Stage 2-3 |
|-------------------|---------------------------|
| Solo 4 frecuencias preset | Necesitas barrer 5-15 frecuencias para pattern matching |
| Bandwidth máximo 200 kHz | No llega a la banda crítica de pared celular |
| DC offset compensation limited | No maneja 50-280 mV típicos en suelo crudo |
| Power 1-3 mA active | Muy alto para sample rate alto multi-frec |
| Mixer/DSP fijos | No puedes implementar custom phase-coherent demod |

**Tu chip custom puede hacer**:
- Frecuencias programables vía DDS
- Bandwidth hasta 500 kHz (3.3V swing)
- AC coupling con auto-zero (OQ-007)
- Custom mixer con phase coherence para detection sub-LSB
- Lock-in amplifier integration con DSP custom

**Eso es lo que permite intentar Stage 2 + Stage 3.** Sin chip custom, esas etapas quedan fuera de alcance científico.

---

## 5. Output deliverables del programa científico

### Stage 1 deliverables (Q3-Q4 2027)
- Spectral library de organismos representativos
- Time-series dataset etiquetado
- Paper 1: "Multi-Frequency Impedance Spectroscopy for Soil Biological Activity Detection: Custom 180nm CMOS AFE" — IEEE Sensors Journal target
- v1.1 MPW spec con bug fixes identificados

### Stage 2 deliverables (Q1-Q3 2028)
- Zoosporogenesis temporal signature characterization
- Fungus-vs-oomycete classifier (ML model)
- Paper 2: "Event-Driven Detection of Oomycete Zoosporogenesis via Custom IS ASIC" — IEEE Sensors Journal o Sensors and Actuators B
- v2 chip spec con expanded frequencies + lower noise floor

### Stage 3 deliverables (2029-2032)
- Multi-region species classifier
- Production-grade detection model (qPCR-supervised)
- Paper 3: "Species-Level Phytophthora Detection via ML-Augmented IS" — Nature Sustainability target

---

## 6. Conexión con chipathon

Para el chipathon 2026 específicamente, el chip v1 va a **greenhouse research validation Q1-Q2 2027**. Razones:

1. 5-15 chips chipathon no alcanzan para field deployment a escala
2. v1 va a tener bugs que field deployment no puede tolerar
3. Greenhouse genera dataset etiquetado controlado (con qPCR ground truth)
4. Paper requirements del chipathon se cumplen mejor con controlled lab data

---

**Last updated**: 2026-05-08 (chipathon kick-off day)
**Next review**: post Project Proposal Review (jun 12 2026)
