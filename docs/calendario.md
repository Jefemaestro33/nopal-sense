# Nopal-Sense — Calendario y Entregas del PICO Chipathon 2026

> Documento operacional. Sesión por sesión, qué se hace, qué entregamos, cuándo
> hablamos, cuándo escuchamos. Tema oficial del Chipathon: **"Build It. Test It.
> Publish It."**
>
> Server Discord: https://discord.gg/tvZcQzvt7q
> Repo oficial: https://github.com/sscs-ose/sscs-chipathon-2026
> Track principal: **B — Circuits for Sensors** (leads: Camilo Velez, Vipul Sharma)
> Track secundario: **D — AI/LLM-assisted Circuits** (leads: Mehdi Saligane, Saptarshi, Luighi)
> PDK: GF180MCUD (180 nm GlobalFoundries)
> Padring: Workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS)
> Die area: 2935×2935 µm; Core: 2051×2051 µm

---

## 1. Vista global — todas las fases en una tabla

| Fase | Periodo | Foco | Entregable terminal |
|------|---------|------|--------------------|
| 1: Setup & Introduction | 8 may – 29 may (Sem 19-22) | Tooling, tutoriales, presentación de tracks | IIC-OSIC-TOOLS funcional, MENTOR_BRIEFING actualizado |
| 2: Team & Project Planning | 5 jun – 26 jun (Sem 23-26) | Formación de equipos, propuesta formal | **Project Proposal aprobada por mentor (12 jun)** |
| 3: Design & Simulation | 3 jul – 17 jul (Sem 27-29) | Schematic + simulación pre-layout | **Pasar Go/No-go (17 jul) ⚠️ HITO CRÍTICO** |
| 4: Layout & Verification | 24 jul – 28 sep (Sem 30-35) | Layout, DRC/LVS, integración, ESD, padframe | **GDS DRC-clean al Channel Partner** |
| 5: Manufacturing & Testing | post-tape-out (~ene 2027) | Bring-up, medición, paper IEEE | Paper submitted (jul 2027 workshop) |

---

## 2. Tabla maestra de sesiones (todo el calendario)

| Sem | Fecha | Tipo | Sesión | Quién presenta | Tu rol | Entregable user |
|-----|-------|------|--------|----------------|--------|-----------------|
| 19 | Vie 8 may 2026 | 🎓 lecture | Kick-off | Boris Murmann + Mehdi Saligane | Oyente | Discord intro + repo watch |
| 20 | Vie 15 may | 🎓 lecture | Tool Installation | Saroj, James, Mitch, Gaurav, Mauricio, **Camilo (MEMS)** | Oyente activo | Tutorial inversor analog corrido |
| 21 | Vie 22 may | 🎓 lecture | Tutoriales | Peter (MOSbius), **Luighi/Sapta (gLayout FVF)**, Sadayuki (RF) | Oyente activo | FVF understood (input stage TIA) |
| 22 | Vie 29 may | 🎓 lecture | Tutoriales | Juan (MOSbius hands-on), gLayout OTA, **Vipul (full-custom analog)** | Oyente activo | Plan analog blocks por bloque |
| 23 | Vie 5 jun | 📋 deadline | **Team Formation Deadline** | — | **Decidir: solo o equipo** | Equipo declarado en Discord |
| 24 | Vie 12 jun | 👥 review | **Project Proposal Review** | Todos los tracks | **Presentas tu propuesta** | Project_Proposal.pdf |
| 25 | Vie 19 jun | 🎓 lecture | Advanced Topics | **Boris Murmann (Systematic Analog CMOS)** | Oyente | Notas para diseño TIA/bandgap |
| 26 | Vie 26 jun | 🎓 lecture | Analog Design Ideas | **Tim Edwards (CACE)**, Peter (Schematic DB) | Oyente activo | Plan de caracterización |
| 27 | Vie 3 jul | 👥 review | **Schematic Review** | All tracks | **Presentas top schematic** | Schematic top + por-bloque |
| 28 | Vie 10 jul | 👥 review | **Simulation Review (blocks)** | All tracks | **Presentas sims por bloque** | Sim results de cada bloque |
| 29 | Vie 17 jul | 👥 review | **Simulation Review (top) + Go/No-go** ⚠️ | All tracks | **Defiendes top-level** | Top-level sim + cierre Go/No-go |
| 30 | Vie 24 jul | 🎓 lecture | Layout Tutorial | Mitch, Juan (DRC/LVS/PEX) | Oyente activo | Layout strategy de cada bloque |
| 31 | Vie 31 jul | 📋 milestone | **DRC Dry-run #1 → Channel Partner** | — | **Mandas primera GDS** | GDS preliminar |
| 32 | Vie 7 sep | 🎓 lecture | Integration Tutorial | Tim, Juan (padframe, ESD, packaging) | Oyente activo | Plan integración top |
| 33 | Vie 14 sep | 👥 review | **Layout Review (blocks)** | All tracks | **Presentas layouts** | Layouts DRC-clean por bloque |
| 34 | Vie 21 sep | 👥 review | **Layout Review (top) + DRC Dry-run #2** | All tracks | **Presentas top layout** | Top layout integrado |
| 35 | Vie 28 sep | 👥 review | **Verification + Final Chip Review** | All tracks | **Defensa final** | Verification report + final layout |
| TBD | ~oct 2026 | 📋 milestone | **Final Submission** | — | Mandas GDS final | GDS DRC-clean firmado |
| TBD | ~ene 2027 | 📋 milestone | Chips disponibles | — | Bring-up | Test setup, lab cookbook |
| TBD | ~jul 2027 | 📋 milestone | IEEE Workshop | — | **Presentas paper** | Paper submitted |

Leyenda: 🎓 = mentor lecture (oyente) · 👥 = participant review (presentas) · 📋 = deadline / milestone

---

## 3. Sesión por sesión — detalle operativo

### 🟢 Sem 19 — Vie 8 mayo · KICK-OFF (HOY/MAÑANA)

**Tipo:** Mentor lecture
**Presentadores:** Boris Murmann (Stanford emeritus → U Hawaii, autor del libro de referencia analog), Mehdi Saligane (U Michigan, gLayout, Track D lead)
**Duración estimada:** 60-90 min Zoom
**Topic:** Introducción a las 5 fases, los 4 tracks, expectativas, tooling, comunicación

**Antes de la sesión:**
- [x] Docker Desktop instalado y corriendo
- [x] Imagen `iic-osic-tools:chipathon` bajada
- [ ] Joined Discord https://discord.gg/tvZcQzvt7q
- [ ] Watching repo `sscs-ose/sscs-chipathon-2026`
- [ ] Notas a mano (físico) — no improvisar con laptop ya que vas a tomar muchas notas
- [ ] 30 segundos de auto-presentación ensayados

**Durante la sesión:**
- Modo oyente. Cero protagonismo.
- Anotar dates exactas que mencionen, comentarios sobre allocation de slots, mentores que se ven prometedores
- Mantener Discord abierto en otra pestaña — pasa chat paralelo donde participantes preguntan cosas que tú también quieres saber
- Si abren Q&A: máximo 1 pregunta específica. Buena pregunta candidata: *"For Track B with mixed-signal scope, can teams be assigned more than one mentor (digital + analog)?"*

**Después de la sesión (mismas 4 horas):**
- Postear intro en `#general` Discord (4-5 líneas, qué haces, dónde estás, tu repo TT previo)
- Postear pitch de búsqueda de colaboradores en `#2026-track-b-circuits-for-sensors`:
  > *"Mixed-signal sensor hub for agricultural IoT (impedance spectroscopy AFE on GF180MCU). Spec frozen, golden model passing 8/8 tests, first-time mixed-signal designer. Looking for 1-2 collaborators with analog/layout experience. Open-source contribution under Apache 2.0, co-authorship on the IEEE workshop paper. The chip is a building block for an existing AgTech product (Zafra-AgTech) — collaborators get paper + open-source attribution, not equity in the company. DM me if interested."*
- Identificar 3-5 personas a seguir en LinkedIn/GitHub

**Entregable:** ninguno formal. Solo presencia.
**Decisión del día:** ¿solo o equipo? Posteo pitch en Discord, dejo 48 hrs, evalúo respuestas antes del 5 jun.

---

### 🟢 Sem 20 — Vie 15 mayo · TOOL INSTALLATION

**Tipo:** Mentor lecture (mucho material técnico)
**Presentadores y temas:**
- **Saroj** — xschem en GF180 (schematic → layout → SPICE)
- **James Stine** — Charlib (caracterización de standard cells)
- **Mitch Bailey** — DRC/LVS
- **Gaurav** — ORFS tutorial (OpenROAD Flow Scripts)
- **Mauricio Montanares** — LibreLane tutorial
- **Camilo Velez** ⭐ — **Overview de MEMS sensors** ← ESTE ES TU TRACK B LEAD

**Antes de la sesión:**
- [ ] Imagen Docker arrancada y verificada (`docker run --rm -it hpretl/iic-osic-tools:chipathon ls`)
- [ ] Bajado el ejemplo `examples/analog_tutorial/inv.sch` del repo del chipathon
- [ ] Repaso rápido de los 4 videos de YouTube (Saroj, xschem+ngspice+gf180mcu) si aún no
- [ ] Tener una lista de preguntas específicas para Camilo (no se las haces durante, las DM después)

**Durante la sesión:**
- Sigue el tutorial de xschem en vivo en tu pantalla — abre xschem en paralelo a la sesión y reproduce los pasos
- Atención **especial** a la presentación de Camilo (probable última 30 min). Anota: ¿menciona impedance spectroscopy? ¿menciona arquitecturas DDS? ¿muestra ejemplos de electroquímico?

**Después:**
- DM a Camilo: *"Hi Camilo, I'm working on a soil impedance spectroscopy AFE for agricultural IoT. Saw your MEMS overview — would love a 20-min chat about analog architectures for low-frequency electrochemical sensing in GF180MCU. Available next week?"*
- Reproducir el tutorial del inversor end-to-end (schematic → layout → DRC → LVS) en tu máquina. **Si no corre, postea en `#general` antes del próximo viernes.**

**Entregable user (interno):** Tutorial del inversor corriendo end-to-end en tu Docker.

---

### 🟢 Sem 21 — Vie 22 mayo · TUTORIALES (gLayout + RF)

**Tipo:** Mentor lecture
**Presentadores:**
- **Peter Kinget** (Columbia, MOSbius lead) — overview MOSbius
- **Luighi + Saptarshi (Sapta)** — gLayout Tutorial 1: **FVF (Flipped Voltage Follower)**
- **Sadayuki Yoshitomi** (MegaChips Japan) — Analog devices for RF applications

**Por qué te importa:** El **FVF es estructura común para input stage de TIA con auto-range**. Te llevas algo concreto que tu chip va a usar.

**Antes de la sesión:**
- [ ] Repasar qué es un FVF (búsqueda rápida en YouTube)
- [ ] Tener el repo gLayout cloneado: `git clone https://github.com/ReaLLMASIC/gLayout`

**Durante:**
- Si Sapta/Luighi muestran código gLayout: anota el patrón, especialmente cómo definir un cell parametrizado
- Si Sadayuki habla de RF: para ti no es lo más relevante (tu IS llega a 1 MHz max), pero los principios de matching y noise aplican

**Después:**
- Reproducir el tutorial FVF de gLayout en tu Docker
- Si pega: tu input stage del TIA ya tiene primer arquetipo. **Esto te ahorra 2-3 semanas de exploración analog.**

**Entregable user:** FVF generado por gLayout, simulado, DRC-clean.

---

### 🟢 Sem 22 — Vie 29 mayo · TUTORIALES (MOSbius + OTA + ANALOG FULL-CUSTOM) ⭐

**Tipo:** Mentor lecture
**Presentadores:**
- **Juan Sebastian Moya Baquero** — MOSbius hands-on
- **Luighi + Sapta** — gLayout Tutorial 2: **OTA (Operational Transconductance Amplifier)**
- **Vipul Sharma** ⭐ — **Full custom analog design flow** ← TRACK B LEAD #2

**ESTA ES UNA DE LAS SESIONES MÁS IMPORTANTES DE LA FASE 1.**

Vipul te va a dar el flujo completo que TÚ vas a usar para diseñar el TIA, mixer, bandgap. Si solo prestas atención a una de las sesiones de Phase 1, que sea esta.

**Antes:**
- [ ] Lista de preguntas específicas para Vipul (mejores que las de Camilo, porque su area cubre tu necesidad analog crítica)
- [ ] Hojea referencias clásicas: Razavi cap. de bandgap, Allen+Holberg cap. de TIA

**Durante:**
- Atención completa al flujo full-custom de Vipul. Anota: ¿qué herramienta de simulación usa? (probable ngspice + xschem). ¿Cómo hace process corner sweeps? ¿Cómo organiza los testbenches?
- Si menciona **gm/ID design methodology** (curvas en `resources/Sizing/`) — anota meticulosamente

**Después:**
- DM a Vipul: *"Vipul, your full-custom flow lecture answered the questions I had about [X, Y, Z]. I'm doing a TIA + bandgap + mixer in GF180 for soil impedance spectroscopy. Open to a 20-min sync next week to sanity-check my analog scope?"*
- Mismo DM a Camilo si aún no respondió
- Reproducir tutorial OTA de gLayout

**Entregable user:** Flujo full-custom replicado en una celda simple (un OTA gLayout-generated).

**Decisión del día:** Para el viernes 29 ya debes saber si vas solo o con equipo. La deadline formal es el 5 jun pero conviene cerrar antes para tener tiempo de redactar la propuesta.

---

### 🔴 Sem 23 — Vie 5 junio · **TEAM FORMATION DEADLINE** ⚠️

**Tipo:** Deadline (no hay sesión Zoom)

**Acciones:**
- [ ] Si tienes 1-2 colaboradores: registra el equipo en `#chipathon-teams` Discord o donde indique anuncio
- [ ] Si vas solo: declara "solo team" formalmente
- [ ] Empieza redacción del Project Proposal (entregable la siguiente semana)

**Lo que pasa si no entregas a tiempo:** te pierdes la review del 12 jun y entras en lista de "individuos sin equipo" — te asignan a uno por defecto, perdiendo control sobre quién trabaja contigo.

**Decisión irrevocable a partir de aquí:** team composition.

---

### 🟡 Sem 24 — Vie 12 junio · **PROJECT PROPOSAL REVIEW** ⭐⭐ TU PRIMERA PRESENTACIÓN

**Tipo:** Participant review (TÚ presentas)
**Formato esperado:** 5-10 min de presentación + 5-10 min Q&A con mentores y otros equipos

**Qué contiene la propuesta (Project_Proposal.pdf):**
1. **Título y equipo** — Nopal-Sense v1: Mixed-Signal AFE for Soil Impedance Spectroscopy in Agricultural IoT
2. **Track:** B (primary) + D (secondary)
3. **Motivación:** problema real ($100M/año pérdidas Phytophthora aguacate, México #1 exportador mundial), gap en sensores comerciales, primer chip para AgTech mexicano
4. **Architecture overview:** diagrama de bloques, los 3 layers (chip / firmware / VPS)
5. **Scope v1 detallado:**
   - IS a 3 frecuencias fijas
   - Interfaces consolidadas (SPI, 1-Wire, ADC 14-bit + MUX 8-ch)
   - Sleep <1 µA, active <2 mA
   - Padring 88-pin (60 analog + 20 bidir)
   - Power: 3.3V único (cambio del original 1.8V/3.3V dual)
6. **Por qué GF180MCU es el PDK correcto** (HV option para sensores 5V, MIM B caps para feedback TIA, 5 metales suficientes)
7. **Validación pre-tape-out:** plan AD5940 lab + Andisol soil + qPCR pareado
8. **Timeline alineado a las fases del Chipathon**
9. **Riesgos y mitigaciones:** los 3 layers (consolidación / bio-index / species-ID)
10. **Lo que necesito del mentor:** mentor mixed-signal con experiencia en bio-impedance / electrochemistry preferido
11. **Track D angle:** todo el RTL + 50% del schematic plan co-diseñado con Claude AI

**Antes de la presentación:**
- [ ] PDF de 8-12 slides max (no slides muy densas)
- [ ] Practica timing — máximo 8 min, Q&A 10 min
- [ ] **Anticipa 5 preguntas duras:** (1) ¿por qué 1k/100k/1M y no 10k/30k/100k? (2) ¿cómo manejas DC offset del electrodo? (3) ¿por qué solo (si vas solo)? (4) ¿qué literatura respalda biofilm-detection en suelo? (5) ¿qué cortas si scope explota?

**Durante:**
- Habla en inglés. Mantén el ritmo.
- En Q&A, **no defiendas a muerte el scope completo**. Si un mentor dice "scope cuts needed", contesta *"yes, my scope-cut path drops X first, then Y, then Z. Open to discussion."* Eso muestra madurez.

**Después:**
- Edita la propuesta con feedback de mentores en 48 hrs
- Postea versión revisada en tu repo `open-silicon-mx`

**Entregable formal:** `Project_Proposal.pdf` subido a tu repo + presentado en sesión.

---

### 🟢 Sem 25 — Vie 19 junio · ADVANCED TOPICS — BORIS MURMANN ⭐

**Tipo:** Mentor lecture
**Presentador:** **Boris Murmann** — *"Systematic Design of Analog CMOS Circuits"*

**Por qué importa:** Boris es **el** autor de referencia mundial para diseño analog sistemático. Su curso EE628 en Stanford y los materials gm/ID son el estándar de oro. Esta lecture típicamente cubre la metodología de gm/ID que está en `resources/Sizing/` del repo.

**Antes:**
- [ ] Repasa los plots gm/ID en `resources/Sizing/backup/techsweep_gf180mcu_plots/` (NMOS y PMOS 3.3V)
- [ ] Identifica preguntas específicas sobre tu TIA: ¿qué gm/ID elegir para input pair, para output stage, para bandgap?

**Durante:**
- Atención completa. Boris no se repite.
- Si hace ejemplos numéricos: replica los cálculos en paralelo en tu cuaderno

**Después:**
- Aplica gm/ID design a tu input pair del TIA. Documenta en `nopal-platform/v1-pico/analog/sizing.md`

**Entregable user:** Sizing inicial de input pair TIA con gm/ID metodología.

---

### 🟢 Sem 26 — Vie 26 junio · ANALOG DESIGN IDEAS — CACE + Schematic DB

**Tipo:** Mentor lecture
**Presentadores:**
- **Tim Edwards** (Efabless legacy, Magic VLSI) — Introduction to **CACE** (Circuit Automatic Characterization Engine)
- **Peter Kinget** (Columbia) — Schematic Database & Simulations tutorial

**Por qué importa:** CACE automatiza la caracterización post-silicon. Si tu paper IEEE va a tener números reales del chip, CACE es la herramienta. **Tim diseñó toda la cadena open-source que estás usando.** Si te llega a contestar un DM, lo aprovechas.

**Antes:**
- [ ] Repo CACE: `git clone https://github.com/efabless/cace`
- [ ] Lista de measurements que tu chip va a necesitar (impedance accuracy across frecuencias, power consumption por modo, sleep current, ADC INL/DNL)

**Durante:**
- Anota cómo escribir un CACE datasheet template (es la entrada al flujo)

**Después:**
- Empieza tu CACE datasheet preliminar para el chip — esto va a ser el **plan de medición** post-silicio que el programa exige bajo "Test It"
- DM a Tim: *"Tim, working on AgTech sensor chip in GF180. Your CACE lecture clarified the measurement plan — I'm drafting a datasheet template now. Mind if I send it for a sanity check?"*

**Entregable user:** `nopal-platform/v1-pico/measurement/cace_datasheet_v0.yaml`

---

### 🔴 Sem 27 — Vie 3 julio · **SCHEMATIC REVIEW** ⭐⭐ (Phase 3 inicia)

**Tipo:** Participant review (TÚ presentas)
**Formato:** 10-15 min presentación + 10-15 Q&A
**Audiencia:** mentores + otros equipos del track B

**Qué presentas:**
- Top-level schematic del chip completo (en xschem, exportado a PDF)
- Schematics por bloque:
  - DDS (digital phase accumulator + sine LUT + DAC drive)
  - DAC 10-bit
  - Buffer/electrode driver
  - TIA con programmable gain
  - I/Q mixer
  - ADC 14-bit SAR (puede ser un IP integrado de OpenFASOC)
  - Bandgap reference
  - LDO interno (cambio de scope: ahora todo es 3.3V, no 1.8V)
- Testbench plan para cada bloque
- Resultados preliminares de simulación (DC operating point al menos)

**Antes de la presentación (las 6 semanas previas):**
- Sem 23: empieza schematic top en xschem
- Sem 24-25: schematic por bloque, basado en tutoriales de Vipul + gLayout examples
- Sem 26: integration top, primeros DC sims
- Sem antes: rehearsal de presentación

**Durante:**
- Habla rápido pero claro. 1 slide por bloque.
- Cuando un mentor pregunte "¿cómo decidiste W/L?" — referencia gm/ID metodología (Boris lecture)
- Si encuentras que un bloque no tiene sim aún: dilo abiertamente, no lo escondas

**Después:**
- Iterar schematic con feedback en una semana
- Subir schematics a `open-silicon-mx/nopal-platform/v1-pico/analog/schematics/`

**Entregable formal:** Schematics completos + sim plan documentado.

---

### 🔴 Sem 28 — Vie 10 julio · **SIMULATION REVIEW (BLOCKS)** ⭐⭐

**Tipo:** Participant review (TÚ presentas)

**Qué presentas:**
- **Sims completos por bloque**, con mediciones específicas:
  - DDS: spectrum output, phase noise, frequency accuracy
  - DAC: INL/DNL, settling time, output noise
  - TIA: bandwidth, gain accuracy across 6 ranges, input-referred noise
  - Mixer I/Q: conversion gain, image rejection ratio
  - ADC: SNDR, ENOB, INL/DNL, conversion time
  - Bandgap: T-coef ppm/°C, PSRR, line regulation
  - LDO: load regulation, dropout voltage, PSRR
- Process corners (TT, FF, SS, FS, SF) para los críticos
- Temperature sweeps (-10°C a 70°C)

**Antes:**
- Sem 27 + 1: ejecuta toda la simulación en serio, no solo DC. Transient y AC para los analog
- Documenta resultados en tabla por bloque vs. spec target

**Durante:**
- Una slide por bloque con tabla comparativa: **target vs achieved**
- Si un bloque no cumple spec: dilo y di cómo lo arreglas

**Después:**
- Iterar bloques que no cumplan
- Empezar integración top (sims combinadas)

**Entregable formal:** Simulation report por bloque + decisiones de scope-cut si las hubo.

---

### 🔴 Sem 29 — Vie 17 julio · **SIMULATION REVIEW (TOP) + GO/NO-GO** ⚠️⚠️ HITO MÁS CRÍTICO

**Tipo:** Participant review + decisión de continuidad
**Formato:** ~20 min presentación + decisión live de Go/No-go con mentores

**Qué presentas:**
- Simulación top-level del chip completo
- Day-in-the-life simulation: scheduler entra a NORMAL, lee sensores, ejecuta IS sweep, reporta vía SPI, vuelve a sleep
- Análisis de potencia integrada
- Mixed-signal verification (digital y analog interactuando correctamente)
- Status frente a cada REQ de SPEC_FROZEN.md

**Lo que decide Go/No-go:**
- ✅ Top-level simula sin errores → Go
- ⚠️ Algunos bloques fallan pero plan de cierre claro → Conditional Go
- ❌ Top-level no simula o errores fundamentales → **No-go = SALES DEL SHUTTLE**

**Antes (semanas 28-29):**
- **Esta es la semana más densa del proyecto.** Plan de horas: 30-40 horas/semana mínimo.
- Integration testing prioritario sobre cualquier polish

**Durante:**
- Si un mentor expresa preocupación: respira, escucha, contesta con datos
- Si te dan No-go: pide específicamente *"what's the gating criterion to revisit Go status?"* — algunos equipos pueden re-entrar con remediation

**Después:**
- Si Go: empiezas Phase 4 (layout)
- Si No-go: scope-down agresivo y pídeles 1-2 semanas para re-presentar (no garantizado pero a veces ocurre)

**Entregable formal:** Top-level simulation results + status vs. SPEC_FROZEN.

---

### 🟢 Sem 30 — Vie 24 julio · LAYOUT TUTORIAL — DRC/LVS/PEX

**Tipo:** Mentor lecture
**Presentadores:** **Mitch Bailey + Juan Sebastian Moya** (DRC/LVS/PEX)

**Por qué importa:** Layout en analog es 10× más complejo que digital. Mitch maneja los flujos de verificación oficial.

**Antes:**
- [ ] Repaso del DRM (Design Manual del PDK): https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/

**Durante:**
- Anota workflow específico para mixed-signal: separación analog/digital, guard rings, sustrate ties

**Después:**
- Empezar layouts por bloque (digital es OpenROAD/LibreLane automático; analog es Magic + KLayout manual)

**Entregable user:** Plan de layout (qué bloques manuales, qué bloques generados).

---

### 🔴 Sem 31 — Vie 31 julio · **DRC DRY-RUN #1 → CHANNEL PARTNER** 📋

**Tipo:** Deadline / milestone (no Zoom session)

**Qué entregas:** GDS preliminar (puede ser layouts parciales) al Channel Partner para verificación de DRC bajo herramientas comerciales del foundry.

**Por qué importa:** El DRC commercial puede surfar reglas que el DRC open-source (Magic + KLayout) no detecta. Si tu GDS tiene errores nuevos, los descubres con tiempo de arreglar.

**Antes:**
- Layouts integrados (no individuales) en un top GDS
- Run local DRC clean en Magic + KLayout

**Entregable formal:** Primera GDS al Channel Partner.

---

### 🟢 Agosto — VENTANA DE TRABAJO SILENCIOSO

No hay sesiones formales en agosto. Aprovecha:
- Iterar layouts post-feedback de DRC #1
- Empezar simulaciones post-extracción (PEX) que son más realistas
- Preparar integración top con padframe
- Validación de campo del AD5940 en Andisol

---

### 🟢 Sem 32 — Vie 7 sept · INTEGRATION TUTORIAL

**Tipo:** Mentor lecture
**Presentadores:** **Tim Edwards + Juan Moya** — Layout, Top level, ESD, padframe, packaging

**Por qué importa:** Integración con la padring del workshop es no trivial. ESD secundario es crítico para electrodos expuestos al exterior.

**Antes:**
- [ ] Layouts de todos los bloques DRC-clean local
- [ ] Pin assignment ajustado al workshop slot 88-pin

**Durante:**
- Atención a la pad list, pad ordering, ESD secondary cells, power straps

**Después:**
- Iniciar top-level integration con padring oficial

---

### 🔴 Sem 33 — Vie 14 sept · **LAYOUT REVIEW (BLOCKS)** ⭐

**Tipo:** Participant review (TÚ presentas)

**Qué presentas:** layouts DRC-clean por bloque + post-extraction sims comparados con pre-layout sims (degradación esperada).

**Entregable formal:** Per-block layouts DRC + LVS clean + PEX sims.

---

### 🔴 Sem 34 — Vie 21 sept · **LAYOUT REVIEW (TOP) + DRC DRY-RUN #2** ⭐⭐

**Tipo:** Participant review + segunda submission al Channel Partner
**Formato:** 15-20 min presentación

**Qué presentas:** Top-level integrado con padring, ESD secondary, power planning.

**Entregable formal:** Top GDS DRC-clean + segunda submission al Channel Partner.

---

### 🔴 Sem 35 — Vie 28 sept · **VERIFICATION + FINAL CHIP REVIEW** ⭐⭐⭐ DEFENSA FINAL

**Tipo:** Participant review (defensa final)
**Formato:** 20-25 min presentación + Q&A extenso

**Qué presentas:**
- Final chip layout con padring
- Verification report completo (DRC, LVS, ERC, antenna, IR drop)
- Top-level PEX sim
- Status final vs. SPEC_FROZEN.md (qué se cumplió, qué se cortó)
- Plan post-tape-out (bring-up, measurement, paper)

**Antes:**
- Final polish de layouts
- Documentación completa en repo

**Durante:**
- Conviértete en el guía del tour del chip. Domina los detalles.

**Después:**
- Iterar feedback de la review en 1-2 semanas
- Preparar GDS final

**Entregable formal:** Final chip review document + final layouts.

---

### 🔴 Final Submission · **GDS DRC-CLEAN AL CHANNEL PARTNER** 📋 (TBD ~oct 2026)

**Tipo:** Tape-out submission

**Qué mandas:** GDS final firmado, sign-off completo, integration collateral según template.

**Entregable formal:** **Tape-out package**.

---

### 🟢 Phase 5 — Manufacturing & Testing (~ene 2027 +)

**Sub-fases:**
1. **Bring-up (~ene 2027):** Chips llegan, PCB de evaluación, primer power-on, SPI handshake
2. **Characterization (feb-may 2027):** ADC INL/DNL, IS accuracy across frequencies, sleep current real, temperature stability
3. **Field validation (mar-jul 2027):** Andisol + Phytophthora inoculado controlado, qPCR pareado, dataset
4. **Paper writeup (jun-jul 2027):** IEEE workshop paper con measurement results
5. **Workshop presentation (jul 2027):** presentación en venue IEEE

---

## 4. Trabajo paralelo (no en el calendario oficial pero crítico)

### Validación lab AD5940 (semanas 22-26 / fin may - jun)
- Comprar AD5940 evaluation kit ($200-300)
- Construir sondas custom (4 pines stainless steel + guard ring)
- Adquirir aislados de P. cinnamomi (UCR Eskalen Lab o INECOL Veracruz)
- Caracterizar Cole-Cole curves: sano vs infected vs Trichoderma vs Pseudomonas
- **Tener resultados antes del Schematic Review (3 jul) para guiar elección de frecuencias**

### Outreach colaborativo (todo el periodo)
- INECOL Veracruz (Méndez-Bravo, Guevara-Avendaño): aislados + microbioma rizosfera
- INIFAP: parcelas piloto adicionales fuera de Nextipac
- UC Riverside (Eskalen): partner para validación cruzada con su programa USDA
- Universidad Auckland (Williams, Wood): expertise impedance Phytophthora microfluídica

### Salvador / Zafra-AgTech (junio piloto)
- Junio 2026: piloto Nextipac con 50-80 nodos hardware tradicional → genera dataset operacional
- Este dataset alimenta el ML del VPS y al final el paper IEEE 2027

### Repos paralelos a mantener
- `open-silicon-mx/nopal-platform/v1-pico/` — chip
- `Zafra-Agtech/` — sistema completo
- Repo del chipathon donde se vive el código colaborativo

---

## 5. Discord — actividad recomendada

**Diario:**
- Revisar `#chipathon-announcements` y `#chipathon-deadlines`
- Lurk en `#general` para captar contexto

**Semanal:**
- Postear progress brief en `#2026-track-b-circuits-for-sensors` (1 párrafo)
- Reporte de Wednesday según schedule oficial: *"Teams are expected to complete a report by Wednesday of each week"*

**On-demand:**
- DM a mentores específicos después de sus lectures (Camilo May 15, Vipul May 29, Boris Jun 19, Tim Jun 26)
- Responder a preguntas de otros equipos en track B (construye reciprocidad)

---

## 6. Decisiones críticas y sus deadlines

| Decisión | Deadline | Default si no decides |
|----------|----------|----------------------|
| Solo o equipo | 5 jun (team formation) | Te asignan a equipo "leftover" |
| Frecuencias IS finales (1k/100k/1M vs 10k/30k/100k) | 12 jun (proposal review) | El mentor decide por ti |
| Cortar IS a 2 frecuencias o mantener 3 | 17 jul (Go/No-go) | Si scope explota, cortan en review |
| Cortar TIA auto-range a fixed gain | 17 jul | Mismo |
| Cortar I/Q mixer a single-phase | 17 jul (límite) | Mismo |
| Tipo de package (workshop slot vs slot menor) | 5 jun | Workshop slot por defecto |
| Solo bridge AT (ATECC608 externo) o crypto on-chip | YA — está en spec, no | OK |

---

## 7. Riesgo crítico por fase

| Fase | Riesgo principal | Mitigación |
|------|------------------|------------|
| 1 | Tooling no instala bien | Empezar HOY, debuguear en `#general` antes del 15 may |
| 2 | Propuesta rechazada o requiere mucho cambio | Iterar con feedback de Camilo/Vipul antes de la review |
| 3 | **Go/No-go = No** | Tener scope-cut path documentado desde la propuesta |
| 4 | DRC errors finales no resolvibles | Layout tutorials del 24 jul + DRC dry-run del 31 jul tempranos |
| 5 | Chip no funciona | Bring-up methodology de CACE + plan de medición pre-tape-out |

---

## 8. Calendario imprimible (versión condensada)

```
2026
═══════════════════════════════════════════════════════════
MAY  8  ▸ Kick-off [oyente]
MAY 15  ▸ Tools install [oyente] · ⭐ Camilo
MAY 22  ▸ FVF + RF [oyente]
MAY 29  ▸ Full custom analog [oyente] · ⭐ Vipul
─────────────────────────────────────────────
JUN  5  ▸ TEAM DEADLINE 🔴
JUN 12  ▸ PROJECT PROPOSAL ⭐⭐ [presento]
JUN 19  ▸ Boris analog [oyente]
JUN 26  ▸ CACE [oyente] · ⭐ Tim
─────────────────────────────────────────────
JUL  3  ▸ SCHEMATIC REVIEW ⭐⭐ [presento]
JUL 10  ▸ SIM REVIEW BLOCKS ⭐⭐ [presento]
JUL 17  ▸ SIM REVIEW TOP + GO/NO-GO ⚠️⚠️ [defiendo]
JUL 24  ▸ Layout tutorial [oyente]
JUL 31  ▸ DRC Dry-run #1 → CP 🔴
─────────────────────────────────────────────
AUG     ▸ Trabajo silencioso (layouts)
─────────────────────────────────────────────
SEP  7  ▸ Integration tutorial [oyente]
SEP 14  ▸ LAYOUT REVIEW BLOCKS ⭐ [presento]
SEP 21  ▸ LAYOUT REVIEW TOP + DRC #2 ⭐⭐ [presento]
SEP 28  ▸ FINAL CHIP REVIEW ⭐⭐⭐ [defiendo]
─────────────────────────────────────────────
OCT     ▸ FINAL SUBMISSION GDS 🔴
═══════════════════════════════════════════════════════════
2027
JAN     ▸ Chips llegan
FEB-JUL ▸ Bring-up + measurement + paper
JUL     ▸ IEEE Workshop presentation
═══════════════════════════════════════════════════════════
```

---

## 9. Lo que necesitas tener listo en cada milestone

**8 may (Kick-off):**
- Discord, Docker, repo watching ✅

**12 jun (Proposal Review):**
- Project_Proposal.pdf de 8-12 slides
- SPEC_FROZEN.md actualizada (3.3V, 88-pin, slot workshop)
- spi_slave.v corregido a 16-bit
- MENTOR_BRIEFING.md con OQ-006/007/008/009 actualizadas

**3 jul (Schematic Review):**
- Top schematic + por-bloque en xschem
- Sim plan en CACE format

**10 jul (Sim Review Blocks):**
- Por-bloque sim results (DC + AC + transient)
- Process corners para críticos

**17 jul (Sim Review Top + Go/No-go):**
- Top-level day-in-the-life sim
- Status vs SPEC firmado

**31 jul (DRC #1):**
- GDS preliminar al Channel Partner

**14 sep (Layout Blocks):**
- Layouts DRC + LVS clean por bloque + PEX sims

**21 sep (Layout Top + DRC #2):**
- Top integrado con padring + GDS al CP

**28 sep (Final Review):**
- Final layouts + verification report + measurement plan

**Final submission (TBD):**
- GDS DRC-clean firmado

---

## 10. Última nota

Este calendario asume aceptación al programa (probabilidad estimada 85-92%). Asume Go al milestone del 17 jul (probabilidad 45% solo, 70-85% con teammate analog). Asume tape-out exitoso (60-80% condicional a Go).

**Si en cualquier punto no se cumple un milestone, este calendario se reordena.** El documento se actualiza después de cada review oficial.

**Última actualización:** 7 mayo 2026, vísperas del kick-off.
