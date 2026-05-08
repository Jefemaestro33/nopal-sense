# Programa de Investigación Científica — Nopal-Sense

**Versión:** 1.0 (2026-05-08)
**Status:** Active framework
**Owner:** Ernest Darell Zermeño Plascencia

Este documento formaliza el programa de investigación científica que el chip Nopal-Sense habilita. Es la **apuesta técnica** del proyecto: qué preguntas científicas intentamos responder, en qué orden, con qué probabilidad de éxito, y qué hardware/experimentos requiere cada etapa.

El approach es **escalonado** (sequential de-risking). Cada etapa:
- Es independientemente valiosa (puedes monetizar a cada nivel)
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

**Frecuencias relevantes**: 1k Hz (anchor iónico/agua), 30k Hz (bio core), 300k Hz (transición dieléctrica/normalización).

**Hardware suficiente**: v1 chipathon con las 3 frecuencias actuales. No requiere DDS programable wide-range.

**Evidencia previa**: ~50+ papers desde 1990s validan IS para soil biological activity discrimination. Wageningen UR, ETH, UC Davis tienen literatura sólida.

**Plan experimental**:
- 4 condiciones × 5 réplicas = 20 macetas (aprox 4 chips dedicados):
  - Suelo autoclaveado (sterile control, baseline)
  - Suelo natural Nextipac (real-world baseline con microbioma)
  - Suelo + inóculo Trichoderma (fungal positive)
  - Suelo + inóculo Phytophthora cinnamomi (oomycete positive)
- IS sweep cada 6h × 14 días
- qPCR semanal de las 4 condiciones
- Análisis: PCA en feature space → ¿separación clara entre sterile vs activos?

**Output esperado**: Clustering visualmente claro en feature space. Publishable como Paper 1 IEEE Sensors. Demuestra capability del chip.

**Costo**: ~$8-12k USD (cultivos + qPCR + labor + infrastructure básica).

**Valor comercial Stage 1 alone**: $1-2M/año MX market.
- Organic farms (compost monitoring): $5-10/ha/año × 80k ha
- Soil health programs (regenerative ag): $8-15/ha/año × 120k ha
- Recovery plots (post-fumigation): $15-25/ha/año × 30k ha

**Aún sin Stage 2 ó 3, el negocio es viable.**

---

### Stage 2 — Distinguir hongo vs oomiceto

**Pregunta científica**: Dado que detectamos vida hifal, ¿podemos diferenciar si es fungal (paredes de quitina) u oomicete (paredes de celulosa)?

**Probabilidad de éxito**: **65-80%**

**Las diferencias físicas reales**:

| Propiedad | Hongos verdaderos | Oomicetos | Implicación IS |
|-----------|-------------------|-----------|----------------|
| Pared celular polímero | Quitina (N-acetilglucosamina) | **Celulosa** | Más OH → más H-bonding → loss tangent diferente en banda específica |
| Espesor pared | 100-200 nm | 50-100 nm | Capacitancia de pared diferente |
| Septación hifas | Septate (cada 50-200 µm) | **Coenocítica** (sin septos) | Conducción intracelular continua vs segmentada |
| Esteroles membrana | Ergosterol | **Fucosterol** (no ergosterol) | β-dispersion frequency shift ~5-15% |
| Producción zoosporas | NO | **Sí** (post-wet) | **Smoking gun temporal único** |
| Diámetro hifal | 2-10 µm | 3-8 µm | Resonancia geométrica diferente |

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
 │  ╲           ╲___                        │     ╲  │     (6-24h post-wet)
 │  ╲                                       │      ╲ │
 └──────────────                            └──────────────
  0h    24h   48h   72h                      0h    24h   48h   72h
```

Oomicetos liberan zoosporas móviles después de wet events. Hongos NO. Esa redistribución de biomasa intracelular → masa móvil → cambio temporal súbito en IS = **firma de evento detectable**.

**Approach dual**:
1. **Steady-state spectral classification** (ML model trained on cellulose vs chitin signatures): ~50-60% probability
2. **Event-driven temporal detection** (zoospore release post-rain): ~75-85% probability
- Combinando ambos: ~80% probability total

**Hardware**: v1 chip + firmware updates (event-trigger mode + high temporal resolution post-wet). NO requiere v2 hardware necesariamente.

**Plan experimental**:

Pure cultures controladas:
- *Phytophthora cinnamomi* (oomicete target — root rot avocate)
- *Phytophthora infestans* (oomicete control — para validar género)
- *Pythium ultimum* (oomicete diferente género — orden Pythiales)
- *Trichoderma harzianum* (hongo común — control kingdom)
- *Aspergillus niger* (hongo control — diferente filogenia)

20-30 macetas distribuidas en estos 5 organismos + 2 controles.

**Wet-dry cycling protocol** (clave para zoosporogenesis):
```
Cada 7 días en greenhouse:
─────────────────────────
Día 1: regar fuerte (simular lluvia → wet event)
Día 1-3: IS sweep cada 30 min (high temporal resolution)
Día 4-7: IS sweep cada 6h (recovery monitoring)
qPCR weekly de cada maceta
```

**Métricas a buscar**:
- Spectral PCA cluster separation: ¿se separan hongo de oomicete en feature space?
- Wet-event response delta: ¿oomicetos muestran transient post-wet que hongos no?
- Cross-validation: train en 4 organismos, test en 5to → ¿generaliza?

**Costo**: ~$25-35k USD (cultivos + lab time + qPCR scaling + infrastructure).

**Valor comercial Stage 2**: $30-60M/año MX market.
- Avocado farms (Phytophthora threat): $80-150/ha/año × 250k ha
- Citrus (multiple Phytophthora species): $60-120/ha/año × 350k ha
- Soft fruits (berries — Pythium/Phytophthora): $100-200/ha/año × 50k ha

**Stage 2 es donde está el grueso del negocio.**

---

### Stage 3 — Identificar especie específica

**Pregunta científica**: Dado que detectamos un oomiceto, ¿podemos identificar si es P. cinnamomi vs P. infestans vs P. nicotianae?

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
2. qPCR te dice "P. cinnamomi load = X" en muestras adyacentes
3. ML model aprende correlación entre IS pattern y qPCR result
4. Después de N=10,000+ pares (IS, qPCR), el modelo predice qPCR result desde IS solo

**Esto NO es species fingerprinting verdadero. Es estimación supervisada.** Pero "predicción útil" es lo que necesita el negocio, no fingerprinting puro. Si el modelo dice "85% probabilidad que tienes P. cinnamomi >threshold" con accuracy de 75% → es comercialmente accionable.

**Hardware**: v2 mask set con:
- 5-7 frecuencias (vs 3 de v1) para mejor pattern matching
- Lower noise floor para distinguir cellulose vs chitin sutilezas
- Phase precision <0.5° (vs 1° en v1)
- Integration time programmable
- Raw I/Q export (no procesado on-chip)

**Plan experimental** (3-5 años post Stage 2):
- Dataset de 10,000+ nodos × años × multiple infection events
- qPCR ground truth de outbreaks reales (no controlados)
- Multi-region training (Jalisco vs Michoacán vs California — soil microbiome varía)
- Temporal validation (predict X meses adelante)

**Costo total Stage 3**: $300-500k research investment over 3-5 años.

**Valor comercial Stage 3** (cherry on top): $15M premium tier MX market.
- Premium tier service: $200-500/ha/año
- Permite tratamiento targeted (qué fungicida específico, cuándo)
- Ventaja para certificación orgánica (proof of organism ID)

**Si Stage 3 NO funciona**: Stage 1+2 + ML = product complete. **Stage 3 es upside, no make-or-break.**

---

## 2. Cómo cada etapa mapea a generación de chip

```
Stage 1 (presencia)        →  v1 chipathon (3 freq, basic)         ✅ CURRENT SPEC
Stage 2 (kingdom)          →  v1 firmware update + maybe v1.1 MPW   ✅ NO HW CHANGES (firmware)
Stage 2 advanced (events)  →  v1.1 MPW con event-trigger mode       🟡 firmware-only
Stage 3 (species)          →  v2 mask set (5-7 freq, lower noise)   🔴 NUEVO HW

Año:         2027         2028           2029-2030       2031+
Hardware:    v1 chipathon v1.1 MPW       v2 MPW          v2 mask set
Investment:  $0 (free)    $15k MPW       $25k MPW        $400k mask
Validates:   Stage 1      Stage 2 ev.    Stage 3 init    Stage 3 mature
```

**Punto crítico**: el chip v1 chipathon **es suficiente para Stage 1 + parte de Stage 2** (la parte event-driven). El v2 viene cuando ya tienes datos para justificarlo.

---

## 3. Greenhouse pilot — diseño experimental concreto

### Asignación de chips por organismo (10 chips disponibles)

| Chip | Organismo | Reino | Razón estratégica |
|------|-----------|-------|-------------------|
| 1 | **Esterilizado control** | — | Baseline absoluto. Suelo autoclaveado, sin inóculo. |
| 2 | **Suelo natural Nextipac sin inóculo** | mixto | Real-world baseline (microbioma natural sin Phytophthora) |
| 3 | **Phytophthora cinnamomi** | Oomicete | TARGET principal. Causa root rot avocate. |
| 4 | **Phytophthora cinnamomi (replica)** | Oomicete | Replica para statistical power |
| 5 | **Phytophthora infestans** | Oomicete | Mismo género diferente especie. Stage 3 question. |
| 6 | **Pythium ultimum** | Oomicete | Mismo orden, diferente género. Test sensitivity. |
| 7 | **Trichoderma harzianum** | Hongo | Antagonista común. Distinguir hongo vs oomicete (Stage 2) |
| 8 | **Aspergillus niger** | Hongo | Hongo bien caracterizado. Control kingdom. |
| 9 | **Bacillus subtilis** | Bacteria | Control de scale (bacteria <<< hifa) |
| 10 | **Spare / calibration** | — | Backup, o usado para repetir si chip falla |

**10 chips perfectamente asignados a 8 condiciones experimentales + 2 controles.**

### Protocolo temporal por chip

```
Día 0:              Día 14:                Día 30-180:
Setup chip          Inoculación            Long-term measurement
en maceta           organismo              + qPCR weekly
+ baseline IS       + IS measurement       + IS continuous
                    pre-/post-              + environmental data
                                            + wet-dry cycles
```

**Total experimental time**: 6 meses por chip = sincronizado entre chips → comparación directa.

### Wet-dry cycling para Stage 2 detection

Cada 7 días:
- Día 1: irrigation fuerte (simulate rain → wet event)
- Día 1-3: IS sweep cada 30 min (high temporal resolution para captar zoosporogenesis)
- Día 4-7: IS sweep cada 6h (recovery monitoring)

**Esperado**:
- Oomicetos (P. cinnamomi, P. infestans, Pythium): spike Z(ω) en banda 30-100 kHz a las 6-24h post-wet
- Hongos (Trichoderma, Aspergillus): no spike, respuesta monotónica
- Controles: cambios solo atribuibles a humedad física

### Infrastructure budget

| Componente | Costo USD | Notas |
|------------|-----------|-------|
| Greenhouse space | $0-3,000 | UdG/CINVESTAV/ITESO posiblemente free |
| 30 macetas grandes (3 por chip) | $200 | 3 réplicas técnicas/chip |
| Avocado seedlings × 30 | $300-600 | De vivero local |
| Soil sterilization (autoclave) | $200 | Lab access |
| Pure cultures × 7 organismos | $0-1,400 | Often free from research labs |
| qPCR access (200 samples / 6 meses) | $6,000-15,000 | Mayor costo |
| Climate control (humidifier, T logger) | $500-1,000 | |
| 10 PCBs bring-up | $1,000-2,000 | $100-200 c/u |
| Cables shielded + electrodos × 40 | $400-800 | 4 electrodos por chip |
| DAQ infrastructure | $200 | 1 ESP32 master collecting |
| Storage 1 TB | $50 | |
| Lab tech part-time 6 meses | $3,000-6,000 | Si subcontratas |
| **TOTAL** | **$12,000-30,000** | |

---

## 4. Math del de-risking sequential

Las probabilidades se **multiplican** si fallas, pero los valores se **suman**:

### Si solo Stage 1 funciona (P=0.90)
- Producto: soil biological activity monitor
- Mercado MX: $1-2M/año
- ROI sobre chipathon (~$0): infinito

### Si Stage 1 + 2 funcionan (P=0.90 × 0.75 = 0.68)
- Producto principal: phytophthora threat detection
- Mercado MX: $30-60M/año
- ROI sobre $50k investment: 600-1200x

### Si Stage 1+2+3 funcionan (P=0.90 × 0.75 × 0.40 = 0.27)
- Producto premium: species-aware treatment
- Mercado MX: $45-75M/año
- ROI: 1000x+

### El downside total
Probabilidad de que NADA funcione: 1 - 0.90 = **10%**.

**90% probabilidad de que el negocio funcione en algún nivel.**

---

## 5. Riesgos honestos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|-----------|
| No greenhouse access | Baja-Media | UdG/ITESO/CINVESTAV. Backup: rentar invernadero comercial $200/mes |
| Pure cultures hard to obtain | Media | Reach out microbiólogos universidades MX. Some collaborate por co-authorship |
| qPCR cost prohibitivo | Media | Lab partner (CIATEJ, U Politécnica) for processing. Reducir N samples si necesario |
| 6 meses lab work demanding | Alta | Lab tech part-time o student thesis (free labor con autoría) |
| Greenhouse ≠ field translation | Alta | Greenhouse first, field validation viene en v2 |
| Chip v1 bugs afectan data | Media | Calibration extensiva al inicio. 1 chip exclusivo para calibración |
| Multi-organism cross-contamination | Media | Macetas separadas, sterilization between organisms, controls |
| Single-replicate not statistically significant | Alta si solo 1 chip/organism | 2-3 réplicas en organismos críticos (P. cinnamomi) |

**Ninguno es deal-breaker. Todos manejables.**

---

## 6. Output deliverables del programa

### Stage 1 deliverables (Q3-Q4 2027)
- Spectral library de 5 organismos pure cultures + controles
- Time-series dataset etiquetado (~500 MB labeled data)
- Paper 1: "Multi-Frequency Impedance Spectroscopy for Soil Biological Activity Detection: Custom 180nm CMOS AFE" — IEEE Sensors Journal target
- v1.1 MPW spec con bug fixes identificados

### Stage 2 deliverables (Q1-Q3 2028)
- Zoosporogenesis temporal signature characterization
- Fungus-vs-oomycete classifier (ML model)
- Paper 2: "Event-Driven Detection of Oomycete Zoosporogenesis via Custom IS ASIC" — IEEE Sensors Journal o Sensors and Actuators B
- v2 chip spec con expanded frequencies + lower noise floor

### Stage 3 deliverables (2029-2032)
- Multi-region species classifier
- Production-grade Phytophthora score model (qPCR-supervised)
- Paper 3: "Species-Level Phytophthora Detection via ML-Augmented IS in Avocado Soil" — Nature Sustainability target
- Commercial deployment of v2 chip in 1000+ ha

---

## 7. Conexión con chipathon

Para el chipathon 2026 específicamente, el chip va a **greenhouse pilot Q1-Q2 2027**, no a field deployment directo. Razones:

1. **5-15 chips chipathon no alcanzan para field deployment** de 30+ nodos
2. **v1 va a tener bugs** que field deployment no puede tolerar
3. **Greenhouse genera dataset etiquetado** que field no puede dar (sin qPCR ground truth)
4. **Paper requirements del chipathon** se cumplen mejor con controlled lab data

**Mientras tanto**: field pilot Nextipac (jun 2026) usa stack commercial actual. Es bridge state hasta v2 chip ready (~2029-2030).

Ver [`business_model.md`](./business_model.md) para detalles del dual-pilot strategy y migration path.

---

**Last updated**: 2026-05-08 (chipathon kick-off day)
**Next review**: post Project Proposal Review (jun 12 2026)
