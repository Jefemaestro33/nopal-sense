# Nopal-Sense — Plan Estratégico para PICO Chipathon 2026

> Plan estratégico del proyecto **adaptado al concurso**. Distinto de la
> investigación científica (esa va en `briefing.md`) y
> distinto del calendario (ese va en `calendario.md`).
>
> Este documento responde: **¿qué construyo, qué corto, cómo me posiciono, qué
> hago con la IP, cómo defiendo cuando alguien me ataca el scope, y qué estoy
> apostando en este chipathon?**

> **Scope**: este documento cubre la estrategia del **chipathon project**. Detalles operacionales del operador (Zafra-AgTech: revenue model, customer specifics, deployment economics, equipo completo) viven en repo privado del operador, NO aquí.

---

## 1. Qué es Nopal-Sense **en el lenguaje del chipathon**

### 1.1 Track positioning oficial

**Track principal: B — Circuits for Sensors.**
Cita textual del blurb oficial 2026: *"applications like water quality
monitoring, environmental sensing, healthcare, smart infrastructure"*. Tu chip
encaja en "environmental sensing" (suelo agrícola es un caso de environmental
sensing).

**Track secundario: D — AI/LLM-assisted Circuits.**
Todo el RTL fue co-diseñado con Claude AI. Significativa parte del schematic
plan también. Mencionar Track D en la propuesta te da puntos de innovation
extra **sin trabajo adicional**.

### 1.2 Frase para mentor matching (la primera vez que te preguntan qué haces)

> *"I'm designing a mixed-signal AFE in GF180MCU for impedance spectroscopy in
> agricultural soil. The chip consolidates 5 commercial sensors into one die
> with an additional measurement channel that no off-the-shelf product offers:
> low-frequency biological activity sensing in the rhizosphere. Built on top of
> the architecture lineage from the 2022 Tennessee electrochemical water
> quality chip. Looking for analog mentor with bio-impedance or instrumentation
> experience."*

Tres claves del pitch:
1. **"Built on the lineage of 2022 Tennessee"** — anclas tu chip a un precedente
   del programa. No eres un outsider, eres continuidad.
2. **"Mixed-signal AFE for impedance spectroscopy"** — vocabulario académico
   estándar, no marketing.
3. **"Looking for analog mentor with bio-impedance"** — tu *ask* específico.
   Mentores que se identifican van a acercarse.

---

## 2. Lo que va EN v1 vs lo que se queda AFUERA

### 2.1 Scope incluido (v1 PICO 2026)

| Bloque | Por qué entra | Riesgo de cumplir |
|--------|---------------|-------------------|
| DDS para 3 frecuencias IS | Sin esto no hay IS | Bajo (digital) |
| DAC 10-bit | Conversión a tensión analógica | Medio |
| Buffer/electrode driver | Maneja impedancia variable de suelo | Medio |
| TIA con programmable gain (4-6 niveles) | Auto-range para 100Ω–1MΩ | **Alto** |
| Mixer I/Q (switching) | Demodulación cuadratura | Medio-Alto |
| ADC SAR 14-bit | Resolución para 3% IS accuracy | Medio (puede ser IP existente) |
| Bandgap precision | Referencia para todo el analog | Medio |
| LDO 3.3V on-chip | Cambio de scope: ahora todo es 3.3V único | Bajo |
| SPI slave (host ESP32) | Interfaz obligada | Bajo (digital) |
| 1-Wire master (DS18B20) | Sensor temperatura externo | Bajo |
| Pulse counter ×2 | EC probe + opcional rain gauge | Bajo |
| Sleep controller + wake timer | <1 µA target | Bajo |
| Register bank 32×16 | Storage de mediciones | Bajo |
| Alert engine (8 comparadores) | Wake ESP32 on threshold | Bajo |

### 2.2 Scope cortado (a v2 o a firmware ESP32)

| Función diferida | Bridge en v1 | Razón del corte |
|------------------|--------------|-----------------|
| Hardware I2C master | Bit-banged en state machine | Área + complejidad |
| FeRAM on-chip | SPI master a FM25V20A externa | Área masiva |
| Fuzzy extractor PUF + AES | PUF simple + ATECC608 externo | Cripto serio = otro chip |
| Tamper detection sofisticado | TAMPER pin + reed switch | Complejidad analog |
| Secure boot completo | Firmware ESP32 valida | Área + complejidad |
| ML accelerator on-chip | Inferencia en VPS | Innecesario v1 |
| Barrido IS programable | 3 frecuencias fijas | Foco v1 |
| LDO 1.8V dual domain | **Eliminado: PDK no soporta 1.8V core** | Restricción PDK |
| JTAG formal | SPI debug mode 0xDE | Pin count |
| Auto-diagnóstico autónomo | Firmware ESP32 + registros | Complejidad |

### 2.3 Plan de scope-cut **si las cosas explotan en julio**

Orden de cortes (de menos doloroso a más):

**Cut 1 (poco doloroso):** Quitar 1 de los 3 IS frequencies. Pasas a 2 (1k +
100k, drop el 1M). El barrido se vuelve más limitado pero el biofilm-band sigue
cubierta.

**Cut 2 (mediano):** Cambiar TIA auto-range a single-gain (elegir el más
útil para suelo Andisol, ~10kΩ). Sin auto-range pierdes parte del rango
dinámico pero simplificas el bloque más complejo del chip.

**Cut 3 (mediano):** Cambiar mixer I/Q a single-phase (solo I, sin Q). Pierdes
la separación magnitud/fase en hardware; lo recompones en firmware
post-acquisition.

**Cut 4 (doloroso):** Mover ADC a un macro existente de OpenFASOC en lugar
de diseñar uno custom. Pierdes ENOB pero ganas tiempo.

**Cut 5 (último recurso):** Reducir scheduler a 2 modos (sleep + active),
eliminar ALERT y VALIDATION. El firmware ESP32 compensa.

**Si después de Cut 5 sigue sin cerrar:** el chip se vuelve "consolidación de
sensores tradicionales con un canal IS extra a 100kHz". Sigue siendo silicio
publicable, sigue siendo más útil que nada en el mercado, sigue siendo paper.

---

## 3. Las 3 capas de valor — explicadas para el mentor

Esta es **la** sección que importa para defender el proyecto contra ataque
escéptico. Memorizar.

### Capa 1 — Consolidación de sensores (RIESGO BAJO, certeza alta)

**Promesa:** El chip consolida EC probe + 3 sensores capacitivos de humedad +
ADS1115 externo + signal conditioning en **un solo die** + sondas pasivas.

**Por qué es certera:**
- Precedentes: 2022 Tennessee electrochemical water, ASIC bio-impedance
  Kassanos TSMC 0.18µm, AD5933/AD5940 comerciales
- Física: las 3 frecuencias bio-band (10 / 30 / 100 kHz) cubren el pico β-dispersion + transferencia de carga membrana — la zona donde aparecen las firmas eléctricas de actividad hifal /
  transferencia de carga / permitividad dieléctrica. Bien estudiada (Kelleners
  2009, Loewer 2017)
- Significant BOM reduction per node + battery life extension (specific
  numbers in operator's private repo).

**Si solo esto funciona, el chip ya es exitoso.** Es el "fall-back con dignidad".

### Capa 2 — Índice de actividad biológica (RIESGO MEDIO, plausible no probada)

**Promesa:** En la banda 10-100 kHz, perturbaciones causadas por biofilms
microbianos en la rizosfera son detectables como anomalía estadística sobre la
firma Cole-Cole del suelo sano.

**Por qué es plausible:**
- Biofilms en cultivo líquido detectables por EIS (Magar 2021, Funari 2022)
- Metabolt device (Sánchez-Cano 2020) detecta firmas metabólicas en suelo
- Física: biofilms reducen R_ct, aumentan C_DL — efecto medible

**Por qué no es certero:**
- Ningún paper publicado lo demuestra en suelo agrícola heterogéneo
- Variables confusoras: temperatura, humedad, salinidad, arcillas, drift
- Señal biológica es perturbación pequeña sobre fondo geofísico grande

**Status:** **hipótesis de research a validar con qPCR pareado en 2027**.
NO es feature de producto en v1.

### Capa 3 — Detección especie-específica de Phytophthora (RIESGO ALTO, no viable hoy)

**Status:** Sin biorreconocimiento (anticuerpos/aptámeros), no defendible.
**Roadmap:** v2 (2028+) con arquitectura distinta, electrodos funcionalizados,
estudios de inoculación controlados a 3-5 años.

**No vendemos esto como feature en el chipathon.** Lo mencionamos solo como
*"motivating long-term research direction; not in v1 scope"*.

---

## 4. Diferenciadores frente a otros equipos del Chipathon

### 4.1 Geográfico — México, primer participante

Datos duros:
- 0 chips fabricados independientemente desde México (per investigación propia)
- LatAm tiene Brasil, Chile, Argentina, Uruguay, Colombia en historial PICO
- México: 10,000+ ingenieros en Intel/AMD/NXP/Marvell GDL pero cero startup
  fabless con chip propio
- El programa **explícitamente encourages "geographical regions
  underrepresented in IC design community"**

Ángulo: **eres representación neta para el programa.**

### 4.2 Aplicación con mercado real ya operando

Market context público:
- Aguacate: México #1 exportador mundial, ~$3B USD/año en exportaciones
- Phytophthora cinnamomi: $100M+ USD/año en pérdidas mexicanas reportadas

Operational backing: existe operador (Zafra-AgTech) con piloto comercial activo en Jalisco. Detalles operacionales (modelo de negocio, customers, equipo completo, deployment economics) en repo privado del operador.

La mayoría de equipos PICO son académicos diseñando building blocks. Tú vienes
con **operational backing real**. Eso es raro.

### 4.3 Pipeline de medición ya construido

El tema oficial 2026 es **"Build It. Test It. Publish It."**. La mayoría de
equipos llega a "Build" pero falla en "Test" porque no tienen lab, no tienen
muestras, no tienen partners. Tú llegas con:

- Andisol caracterizado (suelo volcánico de Jalisco)
- Background de field deployment con commercial sensors
- Pipeline operacional activo del operador (specifics en repo privado)
- Partner potencial con qPCR (INECOL Veracruz, UCR Eskalen Lab)
- AD5940 lab plan documentado (mayo-junio 2026)

### 4.4 Documentación superior al promedio

Repo `open-silicon-mx`:
- 17 documentos de research sobre la cadena de semiconductores y México
- SPEC_FROZEN.md con 75+ requisitos numerados
- ARCHITECTURE.md con design rationale por bloque
- PIN_ASSIGNMENT.md con workshop slot 88-pin pad map (reescrito 2026-05-13)
- MENTOR_BRIEFING.md de 1 página
- Golden model Python de 1,212 líneas con 8/8 tests pasando
- Modelo Randles de física del suelo

Comparado con la mayoría de los repos públicos del Chipathon 2025: 1-2
README, código incipiente. Tu prep está en el percentil top.

### 4.5 Track D (LLM-assisted) bonus gratis

Todo el RTL co-diseñado con Claude AI. El golden model también. Esto es
exactamente lo que Mehdi Saligane premió en 2024 con gLayout. Te metes a Track
D sin trabajo extra.

### 4.6 Chip previo (Tiny Tapeout) ya pasó precheck

Ya hiciste un chip antes (cellular automaton VGA en SKY130). GDS generado,
7/7 tests pasan, precheck PASS. Esto te quita el riesgo de "primera vez con el
flujo". Te coloca en el percentil ~30% de credibilidad técnica desde el día 1.

---

## 5. Estrategia solo vs. equipo (la decisión más importante)

### 5.1 La verdad sobre IP en este chipathon

Hechos no negociables:
- El chip va a ser open-source bajo Apache 2.0. **Sí o sí.** El programa lo
  exige. Cualquiera puede tomar el GDS y mandarlo a fabricar.
- El **moat real del operador** son: (a) algoritmo propietario en VPS, (b) dataset histórico + muestras pareadas qPCR futuras, (c) relaciones comerciales (operacionales del operador), (d) integración del sistema completo (firmware + dashboard + servicio), (e) narrativa de fundador. Detalles específicos viven en repo privado del operador.

**Conclusión:** El chip es un **componente** que el operador usa, no es el negocio del operador.
Si un competidor commercial vendiera mañana un chip mejor, lo usarían y el negocio del operador seguiría siendo el mismo (porque el moat real es algoritmo + dataset + relaciones, no el chip).

### 5.2 Modelo de colaboración: open-source contributors, no co-founders

Si vienes con teammate(s), ofreces:
- ✅ **Apache 2.0 attribution** en chip GDS + Verilog (obligatorio igual)
- ✅ **Co-authorship en el paper IEEE workshop** (estándar académico)
- ✅ Visibilidad del proyecto público (CV credential)

Lo que NO ofreces:
- ❌ Equity en Zafra-AgTech
- ❌ Acceso al algoritmo Phytophthora v3+ (trade secret)
- ❌ Acceso al dataset propietario
- ❌ Derechos sobre v2 commercial (separate project, separate terms)

### 5.3 Filtrado de candidatos (perfecto)

Quien quiera CV/paper → te dice que sí. Win-win.
Quien quiera equity → te ignora. Filtro perfecto, no querías a esa persona.
Quien sea ambiguo → DM directo: *"what are you optimizing for?"*

### 5.4 Decisión recomendada

**Buscar 1-2 colaboradores con experiencia analog/layout.** Razones:

1. **Probabilidad de cerrar el chip:**
   - Solo: ~25-45% probabilidad de tape-out exitoso
   - Con 1 analog senior: ~60-75%
   - Con equipo balanceado de 3: ~70-85%

2. **El bottleneck no es la idea, es el TIA + bandgap + mixer en 4 meses con
   primera experiencia mixed-signal.** Sin ayuda, marginal.

3. **Costo real de teammates:** zero — no comparten Zafra, comparten paper +
   atribución open-source que el programa exige de todos modos.

### 5.5 Plan de búsqueda en Discord

**Día 1 (mañana 8 may, post-kick-off):** Postear pitch en
`#2026-track-b-circuits-for-sensors` con scope explícito de
"open-source-only collaboration".

**48 hrs después:** Evaluar respuestas. DMs a candidatos prometedores.

**Semana del 15-22 may:** 20-min screening calls con 2-3 candidatos.

**Semana del 22-29 may:** Decisión final + acuerdo simple por email
(template abajo).

**Deadline:** equipo formado antes del 5 jun (team formation deadline).

### 5.6 Template de acuerdo (correo de 5 líneas)

```
Subject: Nopal-Sense Chipathon collaboration — scope agreement

Hi [Name],

Confirming our collaboration on the SSCS PICO Chipathon 2026 project
"Nopal-Sense v1: AFE for soil impedance spectroscopy". Scope:

- Apache 2.0 attribution on chip GDS + Verilog (per Chipathon license)
- Co-authorship on IEEE workshop paper based on contribution
- No equity in Zafra-AgTech (the AgTech company that uses this chip
  as a component)
- Phytophthora algorithm + field dataset are not part of this project
- Future commercial chip versions (v2, 2028+) are a separate project
  with separate terms

You'll be responsible for [specific blocks]. I'll cover [other blocks].
Mentor sessions and reviews are joint.

Reply "agreed" if this matches your understanding.

— Darell
```

---

## 6. Mentor matching — qué pides explícitamente

En tu propuesta y en DMs:

> *"Please assign a mentor who has taped out mixed-signal designs with
> on-chip ADCs and analog front-ends, ideally with biosensing,
> instrumentation, or electrochemical measurement background."*

Mentores del programa que matchean este perfil (en orden de preferencia):

1. **Vipul Sharma** — Track B lead #2, full-custom analog. Lecture 29 may.
   Probabilidad alta de matching dado que eres su track.
2. **Camilo Velez** — Track B lead #1, MEMS sensors. Lecture 15 may.
   Bueno para sensores en general aunque su área es MEMS.
3. **Boris Murmann** — capacidad mixed-signal mundial, pero típicamente da
   lectures, no es mentor 1-on-1 directo.
4. **Tim Edwards** — CACE / measurement post-silicon. Para Phase 5.
5. **Kwantae Kim** (U Zurich) — analog generalist, podría ayudar.

**Si te asignan un mentor digital-only:** plan B en MENTOR_BRIEFING.md
ya documentado: "scope down a sensor hub simple, drop IS to v2" — pero
preferimos preservar IS si conseguimos buen matching.

---

## 7. Qué construyo, qué pruebo, qué publico

Mapeo explícito al tema oficial 2026 ("Build It. Test It. Publish It."):

### 7.1 BUILD IT (mayo 2026 - sept 2026)

- Schematic + layout del chip Nopal-Sense v1
- DRC/LVS clean GDS
- Tape-out al Channel Partner

**Entregable:** Final GDS firmado.

### 7.2 TEST IT (ene 2027 - jun 2027)

Chip llega ~ene 2027. Plan de medición (CACE datasheet):

**Caracterización electrical (ene-feb):**
- DC: power consumption (sleep, normal, validation), supplies stability
- AC: ADC SNDR/ENOB/INL/DNL, TIA bandwidth + gain accuracy, mixer image rejection
- Bandgap: T-coef ppm/°C, PSRR, line regulation
- Sleep current: <1 µA target verification
- IS magnitude/phase accuracy contra impedancias conocidas (load box)

**Validación de campo (mar-jun):**
- Andisol soil samples 5 humidity × 3 temperatures
- P. cinnamomi inoculated controlled samples (UCR Eskalen Lab partner)
- qPCR-paired ground truth (RPA-LFD primers Pcinn13739)
- Comparison vs commercial AD5933 + AD5940 evaluation kit

**Entregable:** Measurement report con figuras + dataset público.

### 7.3 PUBLISH IT (jun 2027 - jul 2027)

Paper IEEE workshop:
- **Tier 1 paper:** AFE design (architecture, simulation, measurement) +
  application to soil sensing. Workshop venue.
- **Tier 2 paper (si hay tiempo):** Validation IS-vs-qPCR for biological
  activity correlation. Sensors and Actuators B o similar.

**Entregable:** Paper submitted al workshop IEEE julio 2027.

---

## 8. Riesgos del proyecto y planes de contingencia

### 8.1 Riesgo: aceptación al programa

**Probabilidad:** baja (8-15% de no aceptarte)
**Mitigación:** propuesta del 12 jun con scope limpio + diferenciadores
**Si pasa:** otros programas para 2026 (chipIgnite SKY130 ~$15K, IHP MPW gratis,
wafer.space ~$8K). El proyecto sobrevive sin PICO, solo cambia el shuttle.

### 8.2 Riesgo: Go/No-go negativo (17 jul)

**Probabilidad:** 35-55% solo, 15-30% con equipo
**Mitigación:** scope-cut path documentado, pre-validación AD5940 antes del
schematic review (3 jul), mentor weekly check-ins
**Si pasa:** scope masivo cut a v1-minus, re-presentar 1-2 semanas después.
Algunos equipos PICO han re-entrado bajo remediation.

### 8.3 Riesgo: tape-out exitoso pero chip no funciona

**Probabilidad:** 20-40% (es analog primer intento, esto es normal)
**Mitigación:** PEX sims rigurosos, process corner análisis, Monte Carlo
**Si pasa:** paper de "lessons learned" sigue siendo publicable. Datos de qué
funcionó y qué no son contribución científica válida.

### 8.4 Riesgo: IS biological signal no detectable

**Probabilidad:** 50-70% (basado en literatura)
**Mitigación:** El chip ya es exitoso en Capa 1 (consolidación). Capa 2 es
upside.
**Si pasa:** reframe a "EC/VWC/T consolidado + índice de anomalía
biológica". Sigue siendo 3× mejor que sensores comerciales.

### 8.5 Riesgo: nadie quiere colaborar bajo el modelo open-source-only

**Probabilidad:** 30-50%
**Mitigación:** post claro en Discord, screening calls, segundo intento
después de Project Proposal Review
**Si pasa:** vas solo. Probabilidad Go/No-go baja a ~25-45%. Aceptas el
riesgo. Si el chip falla, sigues teniendo paper sobre la metodología y
documentación de un "primer intento serio mexicano".

### 8.6 Riesgo: scope creep durante el chipathon

**Probabilidad:** 70%+
**Mitigación:** spec freeze del 12 jun firmado por mentor. Cambios post-freeze
requieren revisión formal.
**Si pasa:** cortes en orden documentado (sección 2.3 de este doc).

---

## 9. Métricas de éxito (qué cuenta como ganar)

### 9.1 Éxito mínimo (qué define que valió la pena)

- [ ] Aceptación al programa ✅ (alta probabilidad)
- [ ] Project proposal aprobada (12 jun)
- [ ] Pasar Go/No-go (17 jul)
- [ ] Tape-out completo (oct 2026)
- [ ] Paper IEEE workshop submitted (jul 2027)
- [ ] Primer chip mexicano para AgTech documentado

Si esto se cumple aunque el chip no funcione eléctricamente, **el proyecto fue
exitoso**. Tienes credencial, paper, dataset, lessons learned.

### 9.2 Éxito medio (lo realista)

Anterior + chip funciona en Capa 1:
- [ ] Power-on exitoso
- [ ] SPI handshake con ESP32
- [ ] ADC INL/DNL dentro de spec
- [ ] IS measurement produce datos interpretables a las 3 frecuencias
- [ ] Sleep current <2 µA
- [ ] Validación de consolidación en Andisol pareada con sensores comerciales

### 9.3 Éxito alto (el sueño)

Anterior + Capa 2 muestra correlación con qPCR:
- [ ] Dataset IS + qPCR pareado generado
- [ ] Correlación R² > 0.5 para biological activity vs P. cinnamomi presence
- [ ] Paper Tier 2 publicable (Sensors and Actuators B o similar)
- [ ] Justificación clara para v2 commercial (2028+)

### 9.4 Éxito asimétrico (estructura del bet)

| Outcome | Layer 1 | Layer 2 | Resultado |
|---------|---------|---------|-----------|
| Best case | ✅ | ✅ | Cambia el mercado, paper Tier 1 + Tier 2, fundraising |
| Realistic | ✅ | ❌ o débil | Chip exitoso, paper Tier 1, credencial mexicana |
| Pessimistic | ⚠️ parcial | ❌ | Lessons learned paper, chip TT-equivalent, sigues teniendo Zafra |
| Worst case | ❌ tape-out falla | n/a | Paper sobre metodología, scope-cut documentado, próximo intento más informado |

**Ningún escenario es catastrófico.** Esa es la asimetría correcta.

---

## 10. Lo que NO hacemos en este chipathon

- ❌ **No prometemos detección especie-específica de Phytophthora.** Es Layer 3,
  no es v1. El briefing lo dice explícitamente.
- ❌ **No mostramos al mentor el plan original digital-only.** Está obsoleto.
- ❌ **No defendemos a muerte el scope completo en la review del 12 jun.** Si
  un mentor sugiere cortes, los aceptamos con plan claro.
- ❌ **No comprometemos equity de Zafra a ningún colaborador.** Ese límite es
  firme.
- ❌ **No comprometemos el dataset propietario** ni el algoritmo Phytophthora
  v3+. Esos viven afuera del chip.
- ❌ **No usamos jerga marketing en presentaciones técnicas.** "Disruptive,
  game-changing, revolutionary" no van. "First-of-its-kind in this geography
  for this application" sí va.
- ❌ **No aceptamos tape-out el 11 de septiembre como deadline.** La fecha
  real es TBD ~oct 2026 (final submission). No nos comprometemos a fechas
  no oficiales.

---

## 11. Plan de comunicación durante el chipathon

### 11.1 Discord (canal único oficial)

- `#general` — preguntas amplias
- `#2026-track-b-circuits-for-sensors` — tu canal madre
- `#chipathon-deadlines` — anuncios
- `#chipathon-teams` — formación
- `#chipathon-announcements`

**Cadencia:** semanal weekly brief en `#2026-track-b-circuits-for-sensors`
(1 párrafo de progress) según schedule oficial: *"Teams are expected to complete
a report by Wednesday of each week"*.

### 11.2 GitHub repo `open-silicon-mx`

Mantener actualizado:
- SPEC + architecture + sims + layouts conforme avanzamos
- Issues abiertas para tracking de bugs y decisiones
- Pull requests para cambios significativos (incluso si trabajas solo —
  documenta decisiones)

### 11.3 LinkedIn / outreach externo

Posts ocasionales de progreso:
- Cuando aceptan el proyecto al programa (post #1)
- Cuando pasa Go/No-go (post #2)
- Cuando hay tape-out (post #3)
- Cuando llegan los chips (post #4)
- Cuando hay paper (post #5)

Audiencia: ecosistema mexicano de semiconductores (CINVESTAV, ITESO, Tec, IPN,
Intel/AMD/NXP GDL), comunidad RISC-V LatAm, founders de AgTech.

### 11.4 Zafra-AgTech business comms (separado)

El chipathon es proyecto técnico/académico. Zafra es comercial. Comunicaciones
comerciales (productores piloto, partners, fundraising) no involucran al
chipathon directamente.

---

## 14. Apéndice: cita rápida del valor del chip

**Para inversores / YC:**
*"Every ag-sensing company measures soil at a single frequency. Nobody measures
the frequency-dependent impedance spectrum, which carries distinct signatures
at each band. We're designing a custom chip that consolidates 5 sensors into
one die and adds a measurement channel that doesn't exist in any commercial
product: electrical fingerprinting of microbial activity in the root zone. Even
if the biological channel is noisy, sensor consolidation alone cuts BOM 47%
and extends battery life 100×."*

**Para académicos / IEEE:**
*"Mixed-signal silicon platform on GF180MCU 180nm for multi-band impedance
spectroscopy applied to agricultural soil monitoring. Integrates DDS,
programmable TIA, I/Q demodulator, and 14-bit SAR ADC for simultaneous
measurement of ionic conductivity, dielectric permittivity, and interfacial
dispersion in the 10-100 kHz band as a proxy for biological activity in the
root zone."*

**Para productores aguacateros:**
*"Un sensor de suelo que mide más cosas que los actuales, dura más con una
batería, y con el tiempo va a poder avisarte si hay riesgo de enfermedad en tus
raíces antes de que se vea en el árbol. Se conecta al mismo sistema de alertas
por WhatsApp que ya usas."*

---

**Última actualización:** 7 mayo 2026, vísperas del kick-off.
**Owner:** Ernest Darell Zermeño.
**Track:** B (primary) + D (secondary).
**Repo:** github.com/Jefemaestro33/open-silicon-mx
