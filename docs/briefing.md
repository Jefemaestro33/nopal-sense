# Nopal-Sense: Briefing Técnico-Científico

## Qué es esto

Este documento explica el **chip y su ciencia**: qué es Nopal-Sense, qué ciencia lo respalda, qué riesgos tiene técnicos y biológicos, qué precedentes hay en silicio, y qué inconsistencias arquitectónicas estamos manejando hacia el tape-out de octubre 2026. Es la fuente de verdad técnico-científica del proyecto.

> **Scope**: este documento cubre el chip y la ciencia que habilita. Detalles operacionales del operador (Zafra-AgTech: revenue model, customer specifics, deployment economics, BOM economics, algoritmos propietarios) **NO están en este documento ni en este repo**. Viven en el repo privado del operador. La info aquí es suficiente para entender la apuesta técnica del chip; insuficiente para business due diligence.

Está pensado para que alguien que no sabe nada del proyecto pueda leerlo de
principio a fin y entender la propuesta técnica completa, incluyendo sus fortalezas
reales y sus puntos de fragilidad documentados.

**Documentos hermanos:**
- `plan.md` — estrategia del proyecto adaptada al concurso
- `calendario.md` — sesión por sesión del Chipathon
- `research_program.md` — framework científico de las 3 etapas

**Última actualización:** 8 mayo 2026 (Chipathon kick-off day).

---

## 1. Operational context

El operador del chip es **Zafra-AgTech** — una startup mexicana de agtech enfocada en monitoreo de huertas de aguacate en Jalisco. Su producto combina sensores commerciales de suelo (humedad capacitiva, EC, temperatura), un algoritmo propietario de scoring de Phytophthora v3+, y un dashboard de servicio para productores.

> Detalles operacionales del operador (modelo de negocio, customer specifics, equipo completo, deployment economics) viven en repo privado del operador, NO aquí. Lo que sigue es suficiente contexto para entender por qué se necesita el chip.

**El problema técnico central que motiva el chip:** el scoring actual del operador detecta *condiciones favorables* para Phytophthora cinnamomi, no la enfermedad misma. Cuando los sensores comerciales detectan anomalías, el árbol ya puede llevar meses infectado con daño radicular significativo. Los métodos directos (PCR, espectroscopía de laboratorio) existen pero son caros y lentos.

**El chip propone**: capability nueva (multi-frequency impedance spectroscopy en banda 10-100 kHz) que permite detección biológica directa, complementando el scoring indirecto actual. Es lo que ningún chip comercial provee a costo de campo.

---

## 2. Qué es Nopal-Sense

Nopal-Sense es un chip ASIC mixed-signal que Ernest está diseñando como parte
del IEEE SSCS PICO Chipathon 2026. **Es un especialista de la bio-band, no
un sensor de propósito general.** Cumple tres roles en el nodo Zafra-AgTech:

1. **Agrega una capacidad de medición que no existe en ningún sensor
   comercial:** espectroscopía de impedancia (IS) multi-frecuencia
   **enfocada en la β-dispersion band 10-100 kHz**, donde aparecen las firmas
   electroquímicas de actividad hifal y membrana celular en la rizosfera.
   Esta es **la apuesta científica principal del chip**.
2. **Consolida la infraestructura compartida del nodo:** ADC 14-bit con MUX
   8-canal, voltage reference de precisión, clock distribuido, switches de
   power. El chip lee a los sensores commerciales del nodo (EC probe, sondas
   capacitivas de humedad, DS18B20 de temperatura) a través de su propio ADC
   — **no los reemplaza por IS** porque su banda 10-100 kHz no mide
   conductividad iónica ni permittivity dieléctrica.
3. **Exporta recursos internos** (VREF de 1.2V, clock 1 MHz, power switches,
   interrupt aggregator) que mejoran el rendimiento del nodo completo.

### 2.1 El insight técnico fundamental

Cuando aplicas corriente alterna (AC) al suelo a diferentes frecuencias,
distintos fenómenos físicos dominan la respuesta:

| Rango de frecuencia | Qué mides | Cómo lo obtiene el nodo Zafra |
|---|---|---|
| 100 Hz – 1 kHz | Conductividad iónica (salinidad) | Sonda EC commercial al ADC del chip |
| **10 kHz – 100 kHz** | **β-dispersion: transferencia de carga + membrana celular + biofilms** | **🎯 Nopal-Sense IS (la apuesta científica)** |
| 1 MHz – 10 MHz | Permittivity dieléctrica (water content) | Sondas capacitivas commerciales al ADC del chip |

**La decisión arquitectónica del chip** es enfocar las 3 frecuencias IS dentro
de la banda biológica (**10/30/100 kHz**, OQ-006 = B): 3 puntos en β-dispersion
permiten fit Cole-Cole + clasificador ML multi-feature de zoosporogenesis.
**Las frecuencias iónica y dieléctrica las cubren sensores commerciales** que el
chip lee — eficiencia de specialization vs replicación.

**Restricción física relevante**: a 100 kHz con cable+electrode parasitic
~500 pF, la capacitancia parásita tiene Z_C ≈ 3 kΩ — esto limita el rango
medible del chip a **~100 Ω – 30 kΩ**. Extender frecuencias arriba de 100 kHz
no agrega resolución útil para suelo agrícola; ahogan la señal.

### 2.2 Arquitectura de 3 capas

```
CAPA 1: CHIP NOPAL-SENSE (silicio) — estable, cambia en años
- Impedance Spectroscopy a 3 frecuencias fijas en bio-band: 10/30/100 kHz (OQ-006 = B)
- TIA bio-band-optimized con auto-range 100Ω-30kΩ (3 gain levels)
- ADC 14-bit compartido con MUX 8-ch (lee sensores commerciales del nodo)
- Sleep controller ultra-low-power (<1 µA target)
- Signal conditioning integrado
- Register bank + SPI slave
- VREF + CLK + power switches exportados al nodo
→ Lo que NO cambia: física de medición en hardware (specialization bio-band)

CAPA 2: ESP32 FIRMWARE — actualizable OTA, cambia en semanas
- Coordinación con chip vía SPI
- Alertas locales rápidas
- LoRa TX/RX
- Battery management
- Auto-zero firmware antes de cada IS measurement (OQ-007)
→ Lo que cambia lentamente: protocolos de comunicación

CAPA 3: VPS / CLOUD — totalmente actualizable, cambia en días
- Phytophthora scoring v3 → v4 → v5
- Modelos ML (reentrenables con qPCR real)
- Superficie de calibración Z(ω, T) no-lineal (OQ-008)
- Integración de clima externa
- Dashboard + WhatsApp alerts
→ Lo que cambia constantemente: algoritmos, datos
```

La filosofía de diseño es: **medición física en silicio** (estable, preciso,
eficiente en energía), **protocolos en firmware** (actualizables OTA), e
**inteligencia agronómica en cloud** (iteración rápida). Poner algoritmos en
silicio sería *locking-in* de una versión prematura; poner medición en
software perdería precisión y batería.

### 2.3 Dos versiones del chip (resumen)

**v1 (PICO Chipathon 2026):**
- Tape-out: Final Submission ~oct 2026 (TBD), después del Final Chip Review
  del 28 ago
- Chips en mano: ~ene 2027
- Proceso: GlobalFoundries GF180MCU (variante D)
- Padring: workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS)
- Die: 2935×2935 µm; core: 2051×2051 µm (~3-4 mm² de uso target)
- IS a 3 frecuencias fijas
- Filosofía: "platform-ready" — lo que no cabe se resuelve con bridges externas

**v2 (Comercial 2028-2029, post-validación de v1):**
- Proceso: GF 130 nm o 110 nm
- Volumen target: 10,000+ unidades/año
- Precio/chip: $5-8 USD
- Detalle completo: ver `open-silicon-mx/nopal-platform/v2-commercial/README.md`

### 2.4 Impacto en BOM (qualitative)

El chip consolida múltiples sensores commerciales en un solo die más sondas pasivas. Esto reduce el costo del módulo electrónico, mejora vida de batería (menos chips activos) y reduce puntos de falla (menos componentes discretos).

> Análisis cuantitativo de BOM (números específicos por nodo, savings %, comparison vs alternatives commerciales) es parte del business plan del operador y **vive en repo privado**. Los números públicos generales sobre consolidation savings vienen de literatura standard de IC integration.

**Conceptualmente**: cualquier consolidation IC reduce BOM 30-50% vs commercial discrete equivalents. El chip Nopal-Sense agrega además una capability nueva (IS multi-freq) que NO tiene equivalente commercial — por lo tanto el saving es net-positive aún si el chip es más caro que la suma de partes commerciales que reemplaza.

---

## 3. Precedente PICO Chipathon — Tennessee 2022 ⭐

**El proyecto #13 del Chipathon 2022 fue *"Electrochemical Water Quality
Monitoring"* (equipo USA5, University of Tennessee).** Es el precedente
arquitectónico más directo para Nopal-Sense.

**Por qué importa:**

- Confirma que la familia "AFE electroquímico mixed-signal para sensado
  ambiental" **ya pasó por el comité de selección PICO**. No estamos
  proponiendo algo conceptualmente novedoso para los organizadores —
  estamos extendiendo una línea que ya validaron.

- Tape-out exitoso en GF180MCU. La complejidad mixed-signal del proyecto
  (electrodos + AFE + ADC + signal processing) demostró ser ejecutable en 4-5
  meses con mentorship.

- El mismo programa en su edición 2022 listó proyectos comparables a los que
  Nopal-Sense necesita: CMOS Bandgap Reference (Pakistan3), Low-Power 10-bit
  SAR ADC (USA1, U Alabama + MIT Lincoln Lab), Mix-Pix Mixed-Signal Smart
  Imaging (Chile, U del Bío-Bío). El stack analógico que vamos a construir
  no es desconocido en el ecosistema PICO.

**Qué cambia Nopal-Sense respecto al chip de Tennessee:**

| Dimensión | Tennessee 2022 | Nopal-Sense v1 |
|---|---|---|
| Medio | Agua | Suelo agrícola |
| Espectroscopía | Single-frequency / DC focus | Multi-frecuencia con DDS programable |
| Aplicación | Calidad de agua | Detección biofilms / patógenos en suelo |
| Bridges arquitectónicos | No (chip aislado) | 12 bridges para nodo IoT real |
| Power switches exportados | No | 7× GPIO_SW programables |
| Validación post-silicon | Lab | Lab + campo (Andisol + qPCR pareado) |
| Geografía | USA | México |

**Lección operacional:** si el equipo de Tennessee logró tape-out con scope
electroquímico, un equipo bien preparado con scope similar y el doble de
prep documental puede repetir el éxito.

**Otros chips relevantes del historial PICO 2022-2023:**

| Año | Proyecto | Equipo | Bloque relevante para nosotros |
|-----|----------|--------|-------------------------------|
| 2022 | CMOS Bandgap Reference | Pakistan3 | Bandgap precision (necesario para nuestro VREF) |
| 2022 | Low-Power 10-bit SAR ADC | USA1 (U Alabama + MIT LL) | ADC SAR (nosotros queremos 14-bit) |
| 2022 | Mix-Pix Mixed-Signal Smart Imaging | Chile (U Bío-Bío) | Mixed-signal scope similar |
| 2022 | Sub-Sampling PLL para SerDes | Austria (Kepler Linz) | Clock/PLL design |
| 2023 | Bracolin (filter + LDO + bandgap + SAR ADC) | Brasil + Colombia | Stack analógico parecido |
| 2023 | LTC2 (ADC + DAC + Clock + VRef) | Chile + Korea + Japan | Lista de bloques casi exacta |
| 2025 | ChipOdyssey Readout IC | (en curso) | Categoría funcional idéntica |

---

## 4. PDK reality: GF180MCUD

Esta sección documenta los constraints reales del PDK que Nopal-Sense debe
respetar, después de revisar la documentación oficial y el repo del Chipathon
2026.

### 4.1 Voltages y devices disponibles

- **Standard cells: 3.3V** (librería `gf180mcu_fd_sc_mcu7t5v0`). **No hay
  standard cells de 1.8V**. Esto invalida el plan original "VDD_D = 1.8V via
  external LDO" del SPEC v1.0; v2 de la spec ya cambió a **3.3V único**.
- **Devices analógicos:** NMOS/PMOS 3.3V y 5/6V (HV option), MIM caps Option B
  (entre Top Metal y TM-1, ~2 fF/µm²), poly resistors HRES (`ppolyf_u_1k`).
- **I/O pads:** 5V WR (write rail). Operan a 3.3V con impacto en velocidad.
  Esto es bonus arquitectónico para nosotros: podemos interfacear directo con
  sensores de 5V (DS18B20 acepta 3.0-5.5V; algunas EC probes a 5V) sin level
  shifters.

### 4.2 BEOL stack

- 5 metales (BEOL `5LM`)
- Pasivación: simple
- Top Metal: 11 kÅ
- MIM Option B (TM/TM-1) con densidad 2.0 fF/µm² — **esto es excelente para
  feedback caps del TIA, mixer, y filtros analógicos**
- Single deep nwell option disponible para aislamiento analog/digital

### 4.3 Workshop padring (la realidad del package)

El programa proporciona una **padring fija** para el shuttle 2026:

- Die: **2935 × 2935 µm**
- Core: **2051 × 2051 µm**
- **60 pads analógicos** (`gf180mcu_fd_io__asig_5p0`)
- **20 pads bidir digital** (`gf180mcu_fd_io__bi_24t`)
- **4 DVDD + 4 DVSS** (`gf180mcu_ws_io__dvdd` / `__dvss`)
- **1 clk + 1 rst_n** (single-instance input cells)
- 4 corner cells (insertados automáticamente por LibreLane)

**Implicación para nuestro pinout:** el plan original con QFN-40 (40 pines, 24
señales digitales) **no es directo**. Workshop slot tiene espacio sobrado en
analog (60 vs nuestros ~12 necesarios) pero ajustado en digital (20 bidir vs
nuestras 24 señales).

**Pinout v2 — recortes necesarios (pasamos de 24 a ≤20 digitales):**

| Cortar | Por qué | Bridge alternativo |
|--------|---------|---------------------|
| `EN_LDO` | Eliminado el LDO externo (3.3V único ya no necesita) | n/a — eliminado del scope |
| `CS_MEM` (FeRAM) | FeRAM externa va a v2 | Diferido completamente |
| `PULSE_IN[1]` (rain/wind) | Solo dejamos EC pulse en v1 | Pluviómetro a v2 |
| `TAMPER` muxed con `GPIO_SW[1]` | Reusamos pin como input multiplexado | OK |

Eso nos deja en **20 digitales exactos**, dentro del padring.

### 4.4 Sizing data ya disponible

El repo oficial del Chipathon proporciona caracterización gm/ID para
NMOS/PMOS 3.3V en GF180MCU
(`resources/Sizing/backup/techsweep_gf180mcu_plots/`). Esto incluye:
- I_D/W vs gm/I_D
- V_DSsat vs gm/I_D
- f_T vs gm/I_D
- gm/g_DS vs gm/I_D

**Esto acelera nuestro diseño analog significativamente.** No tenemos que
generar curvas de sizing nosotros — están listas para usar con la metodología
de Boris Murmann (lecture programada para el 19 jun).

---

## 6. Paper de referencia clave: UC Riverside (arXiv 2508.13379)

Bukhari, Roy-Chowdhury et al. publicaron en agosto 2025 un estudio de 6 meses
con 72 plantas de aguacate en invernadero controlado en UC Riverside. Es el
benchmark científico más relevante para Zafra. Hallazgos clave:

**Sobre sensores de suelo:**
- Usaron sensores comerciales de bajo costo (EC + humedad capacitiva, ~$25 por
  unidad) similares a los que Zafra usa hoy.
- Desarrollaron un clasificador jerárquico de dos niveles que primero separa
  plantas afectadas por salinidad vs. no-salinidad, y luego sub-clasifica por
  presencia de PRR.
- Lograron **75-86% de accuracy** entre diferentes genotipos de aguacate,
  superando métodos de ML convencionales por >20%.
- Verificaron viabilidad en dispositivos edge (Raspberry Pi, Jetson) con
  consumo aceptable.

**Sobre espectroscopía óptica (reflectancia de hojas):**
- Usaron un micro-espectrómetro Hamamatsu C12880MA (288 canales, 340-850 nm)
  en un dispositivo handheld portátil.
- Los índices espectrales clásicos (NDSI, NI, N1) fracasaron con el
  espectrómetro barato — no lograron significancia estadística.
- Un SVM multi-wavelength usando los 288 canales completos logró hasta 89% de
  accuracy con significancia estadística real.
- Conclusión: la reflectancia espectral fue la medición foliar más confiable;
  temperatura y EC de hoja fallaron en campo.

**Lo que el paper NO hace:**
- No usa espectroscopía de impedancia (IS).
- No intenta detección directa del patógeno — solo clasifica condiciones del
  suelo asociadas a tratamientos experimentales.
- Fue en invernadero controlado, no en huerto comercial.

**Conexión con Nopal-Sense:** el chip de Zafra busca extender este trabajo
reemplazando los sensores discretos con un solo circuito IS, y agregando el
canal de 10-100 kHz como una feature nueva para el mismo tipo de clasificador
jerárquico.

---

## 7. Investigación de viabilidad — 3 capas de riesgo

Investigación exhaustiva sobre la viabilidad de usar IS para detección de
patógenos en suelo. Hallazgos organizados por nivel de riesgo.

### 7.1 RIESGO BAJO — Capa 1: Consolidación de sensores (PROBADA)

**Promesa:** El chip consolida EC probe + 3 sensores capacitivos de humedad +
ADS1115 ADC externo + signal conditioning en **un solo die** + sondas pasivas
de pines metálicos.

**Por qué es viable:**

1. **IS para humedad y salinidad de suelo: ciencia establecida de 40+ años.**
   Ecuación de Topp, modelos de Loewer, Skierucha, Revil & Skold. Múltiples
   grupos de investigación han construido prototipos de campo con el chip
   AD5933 de Analog Devices (Umar & Setiadi 2015, Politecnico di Bari 2023,
   Loreto et al. 2015). La física de cada banda de frecuencia es bien
   entendida.

2. **ASIC de IS en GF180MCU 180nm: factible.** Existen precedentes directos:
   - **Tennessee 2022 chip electroquímico** (PICO Chipathon, ya fabricado)
   - **Kassanos et al.** — Bio-impedance ASIC, 31 µW, 125 kHz, TSMC 0.18 µm
   - **Rodriguez et al.** — Wideband CMOS impedance spectroscopy AFE en 180nm
   - **OpenFASOC AFE** del Chipathon 2024: ADC SAR 14-bit + opamps + DAC
     capacitivo en este exacto PDK
   - **Mabrains gf180mcu_riscv_soc**: incluye LDOs, bandgaps, osciladores y
     amplificadores on-die

   Los bloques necesarios (DDS, TIA programable, demodulador I/Q, ADC SAR
   14-bit, bandgap, LDOs) están todos dentro de las capacidades de 180nm. Área
   estimada: 1-3 mm² (target 3-4 mm² con margen).

3. **Reducción de BOM y extensión de batería: directa.** Consolidar múltiples chips commerciales en uno custom + reducir cables + duty-cycle agresivo del IS produce mejoras significativas de BOM y batería. Esto **no depende de ninguna hipótesis biológica** — es ingeniería pura. Las economics específicas son operacionales del operador y viven en repo privado.

**Si solo Capa 1 funciona, el chip ya es exitoso.** Es el "fall-back con
dignidad".

### 7.2 RIESGO MEDIO — Capa 2: Índice de actividad biológica (PLAUSIBLE NO PROBADA)

**Promesa:** En la banda 10-100 kHz, perturbaciones causadas por biofilms
microbianos en la rizosfera son detectables como anomalía estadística sobre la
firma Cole-Cole del suelo sano.

**La detección de biofilms por EIS está bien establecida en otros contextos:**
- En cultivo líquido con especies aisladas (E. coli, Salmonella) creciendo
  directamente sobre electrodos interdigitados (Magar 2021, Funari & Shen
  2022, McGlennen 2023).
- En tratamiento de aguas para monitoreo de fouling (múltiples estudios).
- En seguridad alimentaria con bioMérieux BacT/ALERT y similares.

El dispositivo más análogo a lo que Nopal-Sense propone es el **Metabolt**
(Sánchez-Cano et al., Sensors 2020), que usa firmas electroquímicas + sensado
de gases para detectar una "huella metabólica" de actividad microbiana del
suelo. Distingue estados amplios de comunidad (activo vs. dormante) pero NO
identifica especies, y necesitó complementar con sensado de gases para tener
especificidad.

**El salto no probado:** Ninguno de estos estudios trabaja con electrodos
desnudos en suelo de campo heterogéneo. Los estudios exitosos de biofilm usan
líquido limpio, una sola especie, y geometría controlada. En suelo real, la
banda de 10-100 kHz está dominada por:
- Polarización de electrodo (doble capa eléctrica)
- Polarización interfacial Maxwell-Wagner-Sillars de interfaces agua/aire/sólido
- Relajación de contra-iones en arcillas
- Relajación de agua ligada en suelos arcillosos

Un biofilm microbiano (espesor micrométrico, fracción de volumen diminuta
comparada con suelo a granel) produce una perturbación de órdenes de magnitud
menores que estos fenómenos. La pregunta es si esa perturbación es extraíble
con ML sobre datos de series de tiempo, o si se ahoga en el ruido geofísico.

**Veredicto:** Es una hipótesis razonable que vale la pena probar. Nadie la ha
probado en campo. **El riesgo es bajo porque no necesita funcionar para que
el chip tenga valor** — Capa 1 ya lo justifica.

### 7.3 RIESGO ALTO — Capa 3: Detección especie-específica de Phytophthora (NO VIABLE HOY como producto)

La búsqueda no encontró **ningún paper revisado por pares** demostrando una
firma de impedancia label-free para *P. cinnamomi* en suelo. Todos los métodos
publicados de detección de Phytophthora por EIS usan:

- Electrodos funcionalizados con anticuerpos/aptámeros/ADN (biorreconocimiento)
- Captura microfluídica de zoosporas guiada por quimiotaxis (Zhang et al. 2025,
  Universidad de Auckland — detección de zoospora individual de P. cactorum
  en canal de 50 µm)
- Métodos moleculares (PCR, RPA-LFD con gen Pcinn13739, RPA-CRISPR/Cas12a)

**Por qué es difícil en suelo a granel:**
- La rizosfera del aguacate contiene miles de taxones bacterianos y fúngicos.
  *P. cinnamomi* es una fracción diminuta de la biomasa total.
- La infección por *P. cinnamomi* *aumenta* la diversidad microbiana de la
  rizosfera (Solís-García et al. 2021), haciendo más difícil aislar su señal.
- Incluso métodos de VOC (narices electrónicas, mucha más riqueza química que
  impedancia eléctrica) encontraron solo 2 marcadores exclusivos de
  *P. cinnamomi* entre 8 especies probadas (Vergara et al. 2024).
- Sin biorreconocimiento inmovilizado en el electrodo (anticuerpos/aptámeros —
  que impondría uso único, fouling, manufactura regulada), las afirmaciones de
  especificidad a nivel de especie no son defendibles.

**La idea tiene lógica biofísica real:**
- *P. cinnamomi* es un oomiceto (pared de celulosa/β-glucanos), no un hongo
  (pared de quitina). Son materiales dieléctricos distintos.
- Zoosporas biflageladas vs. hifas/esporas pasivas = morfologías eléctricamente
  diferentes.
- En citometría de impedancia biomédica, estas diferencias se leen
  perfectamente — pero en buffer limpio, célula individual, electrodos a
  micrómetros. **No en suelo a granel.**

**El camino más realista:** No buscar la huella de *P. cinnamomi* sola, sino
detectar el *cambio en la huella total del suelo* cuando *P. cinnamomi* está
presente — **detección de anomalías, no identificación de especie**. Eso es
mucho más factible y sigue siendo comercialmente diferenciado.

**Veredicto:** No debería afirmarse como feature de producto sin estudios de
inoculación controlada. Como hipótesis de investigación a 3-5 años, es
exactamente el tipo de apuesta asimétrica que vale la pena tomar.

---

## 8. Landscape competitivo

### 8.1 Sensores comerciales de suelo (ninguno hace IS multi-frecuencia)

| Empresa | Tecnología | Frecuencia | Mide patógenos? |
|---|---|---|---|
| Sentek (Australia) | Capacitiva | ~100 MHz fija | No |
| METER Group (ex Decagon) | Capacitiva | 70 MHz fija | No |
| CropX | Dieléctrica fija | Fija | No |
| Stevens Hydra Probe | Impedancia | 50 MHz fija | No |
| Sensoterra, Dragino, Milesight | Capacitiva/FDR | Fija | No |
| **Nopal-Sense (propuesto)** | **IS multi-frecuencia** | **3 frecuencias programables 1k-1M Hz** | **Índice de actividad biológica (research)** |

### 8.2 Grupos de investigación relevantes

- **UC Riverside (Roy-Chowdhury, Mauter, Bukhari, Eskalen)** — competidor
  directo más cercano. Financiados por USDA-NIFA SCRI ($4.4M, 2020). No usan
  IS aún pero tienen el financiamiento, los huertos y la ventaja inicial.
  Podrían publicar resultados IS en 2026-2027.
- **Universidad de Auckland (Zhang, Williams, Wood, Travas-Sejdic)** — sensor
  microfluídico de impedancia para zoosporas de *P. cactorum* con detección
  de zoospora individual. Precedente significativo pero usa quimiotaxis +
  microcanales, no suelo a granel.
- **Politecnico di Torino / Tel Aviv (Demarchi, Shacham-Diamand)** — EIS
  in-vivo en plantas con microagujas. Hoja/tallo, no suelo.
- **INECOL Veracruz (Méndez-Bravo, Guevara-Avendaño)** — microbioma de
  rizosfera aguacate-PRR en México. Potencial socio de validación.

### 8.3 Chips de IS existentes (ninguno diseñado para agricultura)

- **AD5933 (Analog Devices)** — chip de impedancia más usado en prototipos de
  investigación. ~$10-15/unidad. Limitaciones: un solo resistor de feedback,
  rango de frecuencia limitado.
- **AD5940/AD5941 (Analog Devices)** — versión mejorada, más cara. Corrige
  limitaciones del AD5933.
- **ASICs biomédicos publicados:** Kassanos et al. (31 µW, 125 kHz, TSMC
  0.18 µm), Rodriguez et al. (wideband, 180nm). Apuntan a wearables /
  implantables, no agricultura.

**Ningún ASIC previo ha sido construido específicamente para EIS de suelo
agrícola.** Nopal-Sense sería el primero.

---

## 9. Architectural reality checks ⚠️

Esta sección documenta inconsistencias arquitectónicas detectadas en el SPEC v1
original que requieren resolución antes del Schematic Review (3 jul 2026).
**Cada uno tiene una Open Question formal en la sección 11.**

### 9.1 Tensión en elección de frecuencias IS

**Inconsistencia detectada:** El SPEC v1.0 congela las frecuencias IS en
**1 kHz / 100 kHz / 1 MHz**, asignando una frecuencia por banda física
(iónica / bio / dieléctrica). Pero la *banda biológica* que el briefing
reclama como diferenciador es **10-100 kHz**. Con la asignación 1k/100k/1M,
solo **un punto** (100 kHz) cae dentro de la banda biológica, y al borde
superior. Para una hipótesis Layer 2 seria, conviene tener al menos 2-3
puntos dentro de 10-100 kHz para ajustar un modelo Cole-Cole.

**Tres opciones a discutir con mentor:**

| Opción | Frecuencias | Pros | Contras |
|--------|-------------|------|---------|
| **A: Original (consolidación)** | 1 k / 100 k / 1 M | Una banda física por punto. Validación más amplia. | Solo 1 punto en bio-band. Layer 2 limitada. |
| **B: Bio-centric** | 10 k / 30 k / 100 k | 3 puntos en bio-band. Layer 2 fuerte. | Pierde anchor iónico (1k) y dieléctrico (1M). |
| **C: Híbrida (recomendada)** | 1 k / 30 k / 300 k | Anchor iónico + bio core + transición dieléctrica | Más estrecha que A pero más útil que B para clasificador combinado |

**Resolución 2026-05-13 → Opción B (10 k / 30 k / 100 k):** se prioriza
maximizar puntos en la β-dispersion para sostener Stage 2 (fit Cole-Cole
multi-punto + clasificador ML temporal de zoosporogenesis). Los anchors
iónico (1 kHz) y dieléctrico (1 MHz) se delegan a sensores commerciales del
nodo Zafra (sonda EC + capacitiva al ADC del chip) — vertical integration
permite especialización en lugar de replicación. Además: parasitic Z_C
del cable+electrode (~500 pF) ≈ 3 kΩ a 100 kHz limita el rango medible
útil a ~30 kΩ, sin sentido empujar la 3ra freq arriba de 100 kHz en suelo
agrícola.

### 9.2 DC offset del electrodo y rango dinámico del TIA

**Inconsistencia detectada:** Los electrodos de acero inoxidable inmersos en
suelo agrícola producen potenciales de electrodo DC de **50-200 mV** a partir
del par metal-electrolito y de la actividad redox local (Comeau et al. 2024).
Este offset es lento (se equilibra en horas) y se reactiva tras cada
inserción o limpieza de la sonda.

El TIA del v1 actual no incluye AC coupling ni DC servo loop. En un rail de
3.3V con excitación AC de 100 mVpp y un offset DC realista de 200 mV, el
TIA pierde aproximadamente **12% del rango dinámico** desde el primer minuto
de despliegue. El AGC en 6 niveles solo opera sobre la componente AC. La
consecuencia es accuracy IS degradada en electrodos con offsets atípicos.

**Cuatro alternativas a discutir con el mentor:**

| Opción | Solución | Costo | Recomendación |
|--------|----------|-------|---------------|
| 1 | Cap de bloqueo DC + reset switch periódico | ~0.05 mm² + cap MIM grande + 1 switch | Conservadora, simple |
| 2 | Chopper stabilization | Complejidad timing, ruido inyectado | Compleja para v1 |
| 3 | DC servo loop | ~0.04 mm² + OTA dedicado | Robusta, mediana complejidad |
| 4 | **Auto-zero por firmware** | Cero silicio extra, ~30 ms por measurement | **Recomendada para v1** |

**Recomendación pre-mentor:** **Opción 4 (auto-zero firmware)**. Antes de
cada IS measurement, ESP32 dispara measurement DC con ADC, lo sustrae
digitalmente, luego aplica excitación AC. Si el mentor identifica que esto
es insuficiente para 3% IS magnitude accuracy, pasamos a Opción 1
(cap MIM + reset switch).

**Decisión final:** OQ-007.

### 9.3 Corrección de temperatura no-lineal

**Inconsistencia detectada:** El SPEC REQ-PR-001 implementa corrección de
temperatura **lineal** en Q8.8: `y = a·x + b - α·(T - Tref)`. Pero la
impedancia de suelo a 100 kHz tiene **comportamiento no-lineal con T**
debido a:
- Rotación dipolar del agua (Debye relaxation)
- Movilidad de contra-iones (Arrhenius)
- Cambios de viscosidad del agua porosa

Una corrección lineal Q8.8 no captura esto; subestima sistemáticamente la
deriva en extremos de temperatura (-10°C y 70°C, los corners del spec).

**Decisión arquitectónica:** El chip **exporta T sincrónica con cada Z(ω)**
en los registros del bank. El VPS aprende la **superficie 2D Z(ω, T)** con
ML reentrenable. La corrección lineal en chip se mantiene para alertas
locales rápidas, pero el clasificador final vive en la nube.

**Esto es un *punt to VPS* consciente:** mantener el chip simple y
deterministic, dejar la complejidad del modelo no-lineal en un sistema
actualizable. Documentado en OQ-008.

### 9.4 PSRR de VREF_OUT exportado

**Inconsistencia detectada:** Pin 2 del chip (`VREF_OUT`) exporta la
referencia bandgap interna a sensores externos con **precisión 0.05%**
prometida. Para sostener esa precisión bajo variaciones de supply (±10%) se
requiere PSRR > 60 dB en banda DC-100 kHz.

El SPEC actual no especifica buffer dedicado ni red de compensación. Con
1 µF de cap externo en el pin (per `PIN_ASSIGNMENT.md` GL-005), hay un loop
de estabilidad que puede oscilar bajo cargas reactivas del PCB.

**Tres opciones:**

| Opción | Solución | Costo |
|--------|----------|-------|
| 1 | Buffer dedicado con compensación externa | ~0.05 mm² + 2 pins (filtro RC) |
| 2 | Buffer integrado + cap interno | ~0.08 mm² (cap MIM grande) |
| 3 | Reducir target a 0.5% (10×) | Cero |

**Recomendación pre-mentor:** **Opción 1**. Buffer dedicado en silicio +
red de compensación externa (R_s + C_p) en el PCB. Si silicio está apretado,
fallback a Opción 3.

**Decisión final:** OQ-009 (anteriormente sobre slot, renombrada).

### 9.5 Padring choice — workshop slot

**Decisión tomada:** Workshop slot (88 pads, die 2935×2935 µm). Razones:
- Los slots menores (`slot_0p5x0p5`, `slot_0p5x1`, etc.) no proveen
  suficiente analog pads para nuestros 12 analógicos.
- El workshop slot da margen amplio en analog (60 vs 12 necesarios) y nos
  fuerza a recortar digitales de 24 a 20 (recortes ya documentados en sección
  4.3).
- Es el padring oficial vendored del programa, fork de wafer-space template,
  validado DRC/LVS clean en 2026-04-23.

---

## 10. Riesgos operacionales y desafíos en campo

### 10.1 Variables confusoras

- **Temperatura:** Sondas de impedancia tienen varios % de error de VWC por
  cada 10°C. Las oscilaciones diurnas en un huerto de aguacate pueden ser
  15-25°C. Mitigación: corrección Z(ω, T) en VPS (sección 9.3).
- **Humedad:** Un cambio de 1% en VWC típicamente supera cualquier
  contribución biológica en la misma banda.
- **Salinidad:** Superpone exactamente con la banda donde se busca actividad
  biológica.
- **Heterogeneidad del suelo:** Comunidades microbianas varían más en
  distancias de <1 metro que entre tratamientos experimentales.
- **Drift operacional:** Instrumentos comerciales de EC muestran varios % de
  drift diurno solo por calentamiento.

### 10.2 Fouling de electrodos

Corrosión y biofouling están bien documentados en despliegues de suelo a
largo plazo. Electrodos de pot poroso necesitan horas para equilibrarse y
derivan durante 28 días (Comeau et al. 2024). La geometría, materiales (oro,
platino, acero inoxidable) y recubrimientos protectores son decisiones
críticas — son la diferencia entre 6 meses y 5 años de vida útil. Excitación
AC bipolar mitiga pero no elimina el problema.

### 10.3 BOM realista del nodo completo

El chip a >100k unidades puede costar <$2/die. Pero el resto del BOM (sondas,
PCB, radio LoRa, batería, carcasa IP67, cables) típicamente suma $15-35
incluso antes del margen. **$10 para el módulo electrónico consolidado es
plausible; $10 para el nodo completo desplegado es poco realista** sin
repensar radio, carcasa y batería.

### 10.4 Propiedad intelectual (FTO patents)

Patentes que necesitan revisión de libertad de operación:
- US 10,073,074 — IS de banda RF baja para sensado inalámbrico de suelo in-situ
- US 11,415,612 — sensor dieléctrico complejo de METER Group
- US 11,402,344, 11,598,743 — humedad de suelo + compensación de temperatura

El espacio de "extracción de propiedades de suelo por multiplexación de
frecuencia" está parcialmente ocupado. Acción pendiente: review FTO formal
antes del v2 commercial (2028).

---

## 11. Open Questions formales (OQ-001 a OQ-009)

Lista numerada de las preguntas técnicas abiertas que llevamos al mentor en
mayo. Cada una tiene preferencia documentada y deadline de resolución.

| ID | Pregunta | Opciones | Preferencia pre-mentor | Deadline |
|----|----------|----------|------------------------|----------|
| OQ-001 | Topología de TIA con auto-range en 180nm | Shunt-feedback opamp + FET-switched resistor ladder vs current conveyor variantes | Shunt-feedback opamp + FET ladder (clásico, predecible) | 12 jun |
| OQ-002 | 14-bit SAR ADC en 180nm a 20 kSPS, factibilidad y área | Diseño custom vs IP existente OpenFASOC | IP existente OpenFASOC si calidad suficiente | 3 jul |
| OQ-003 | Mixer I/Q analog vs switching demodulator | Analog multiplier vs Gilbert cell vs switching mux | Switching mux + LPF (área eficiente, adecuado para 14-bit final) | 3 jul |
| OQ-004 | Bandgap quality para 0.05% precision en VREF_OUT exportado | PTAT-CTAT clásico vs chopper-stabilized | PTAT-CTAT con buffer dedicado (sección 9.4) | 3 jul |
| OQ-005 | Cocotb + Spectre AMS flow para mixed-signal | Setup recomendado y herramientas | Por definir con mentor | 12 jun |
| **OQ-006** | **Frecuencias IS finales** | **A: 1k/100k/1M · B: 10k/30k/100k · C: 1k/30k/300k** | **B (resuelto 2026-05-13)** | ✅ |
| **OQ-007** | **Cancelación de DC offset del electrodo** | **1: Cap+switch · 2: Chopper · 3: Servo loop · 4: Auto-zero firmware** | **4 (auto-zero firmware)** | **12 jun** |
| **OQ-008** | **Corrección no-lineal de T: on-chip vs VPS** | **A: Linear on-chip + Z(ω,T) en VPS · B: LUT 2D on-chip · C: Polynomial on-chip** | **A (punt to VPS)** | **3 jul** |
| **OQ-009** | **VREF_OUT buffer + compensación** | **1: Buffer + ext compensación · 2: Buffer + cap interno · 3: Reducir precisión a 0.5%** | **1 (buffer + ext comp)** | **3 jul** |

OQ-006, OQ-007, OQ-008, OQ-009 son decisiones nuevas detectadas en sección 9
(architectural reality checks). Las primeras 5 son las del SPEC original.

---

## 12. Plan de de-riesgo recomendado

1. **Lab (Q1-Q2 2026):** AD5940 + sonda custom de 4 electrodos en macetas.
   Suelo estéril + zoosporas inoculadas de *P. cinnamomi* a concentraciones
   conocidas. Control con *Trichoderma* y *Pseudomonas* saprófitas. Pregunta:
   ¿la firma Cole-Cole a 10-100 kHz difiere entre tratamientos, manteniendo
   humedad/temp/salinidad constantes?

   *Equipo necesario:* AD5940 evaluation board (~$200-300), sondas custom
   (4 pines stainless 5cm con guard ring), fuente regulada, multímetro
   precision, PC con software AD5940 SDK.

   *Aislados *P. cinnamomi*:* contactar UCR Eskalen Lab o INECOL Veracruz en
   primera semana de mayo. Tiempo de obtención: 4-6 semanas.

2. **Mapeo de confusores (Q2-Q3 2026):** Misma sonda bajo temperatura variable
   (5-35°C), VWC (5-35%), EC (0.5-5 dS/m), arcilla/arena/franco.
   Caracterizar el envelope ambiental de cualquier señal biológica.

3. **Piloto de campo con INIFAP/UCR (Q3 2026-Q2 2027):** 50+ árboles en 3-5
   huertos. Ground truth con qPCR (RPA-LFD usando primers Pcinn13739 según
   Dai et al. 2022) cada 4 semanas.

4. **Tape-out (Final Submission ~oct 2026):** ASIC del Chipathon como v1.
   Optimizar para las bandas que el trabajo de lab mostró informativas.

5. **Reframe si es necesario (2027):** Si la especificidad de especie no se
   demuestra, posicionar como "EC/VWC/T consolidado + índice de anomalía
   biológica." Sigue siendo 3× mejor valor que sensores comerciales actuales,
   sigue siendo defendible.

---

## 13. Framing primario (el pitch oficial)

**Esta es la frase que se usa en primera línea en cualquier comunicación
externa, sin excepción.**

> *"Nopal-Sense v1 es un AFE de consolidación de sensores de suelo (humedad,
> salinidad, temperatura) en un solo chip mixed-signal, con un canal adicional
> de probing biológico en banda 10-100 kHz como hipótesis de research a
> validar con qPCR pareado. La detección especie-específica de Phytophthora
> cinnamomi es dirección de investigación a 3-5 años, no feature de producto
> v1."*

Este framing protege contra over-promising mientras deja la puerta abierta a
upside si Layer 2 funciona empíricamente.

---

## 14. Grupos clave para colaboración

- **UC Riverside** — Roy-Chowdhury (CS/ECE), Mauter (Ing. Civil), Eskalen
  (Patología Vegetal). Programa SCRI ($4.4M). El socio natural para
  validación cruzada IS + sensores tradicionales.
- **Universidad de Auckland** — Williams, Travas-Sejdic, Wood. Sensor
  microfluídico de zoosporas. Podrían aportar conocimiento sobre la respuesta
  de impedancia de zoosporas de Phytophthora.
- **INECOL Veracruz** — Méndez-Bravo, Guevara-Avendaño. Microbioma de
  rizosfera aguacate-PRR en México. Acceso a huertos y ground truth biológico.
- **INIFAP** — Red de investigación agrícola federal mexicana. Acceso a
  parcelas experimentales y validación agronómica.
- **Politecnico di Torino / Tel Aviv** — Demarchi, Shacham-Diamand. Expertise
  en EIS de plantas y diseño de sensores.
- **Universidad Autónoma Chapingo / Colegio de Postgraduados** — Patología
  vegetal de aguacate mexicano.

---

## 15. Apéndice — Mentores y leads del PICO Chipathon 2026

Para referencia rápida durante el chipathon:

### Track B (Circuits for Sensors) — TU TRACK PRINCIPAL

- **Camilo Velez** — Track B lead. Lecture sobre MEMS sensors el 15 may.
- **Vipul Sharma** — Track B lead. Lecture sobre full-custom analog flow el
  29 may. **Mentor candidato más probable para Nopal-Sense.**

### Track D (AI/LLM-assisted Circuits) — TU TRACK SECUNDARIO

- **Mehdi Saligane** (U Michigan) — gLayout creator, Track D lead.
- **Saptarshi Ghosh** — Track D, gLayout.
- **Luighi** — Track D + C (gLayout + MOSbius).
- **Mauricio Montanares** — LibreLane, Track D.
- **Osama Khan** — Track D.
- **Trio Adiono / Nur** — Track D.
- **Gaurav** — Track A + D (ORFS, AI/LLM).

### Track A (Foundational Building Blocks)

- **James Stine** — Track A lead, Charlib.
- **Saroj** — xschem GF tutorial.
- **Akhilesh Patil** — Track A lead.
- **Sumanth Kamineni** — Track A lead.

### Track C (MOSbius)

- **Peter Kinget** (Columbia) — MOSbius lead.
- **Juan Sebastian Moya Baquero** — Track C, integration.

### Tooling y soporte transversal

- **Boris Murmann** (U Hawaii, ex-Stanford) — chairman PICO. Lecture 19 jun
  sobre Systematic Analog CMOS Design. Aristotle Award 2024.
- **Mitch Bailey** (Shuhari System) — DRC/LVS.
- **Tim Edwards** (Magic VLSI / Efabless legacy) — CACE, layout. Lecture 26 jun.
- **Harald Pretl** (Kepler U Linz) — IIC-OSIC-TOOLS Docker image.
- **Matt Venn** (YosysHQ Spain, Tiny Tapeout founder) — soporte open-source.
- **Sadayuki Yoshitomi** (MegaChips Japan) — RF analog. Lecture 22 may.
- **Kwantae Kim** (U Zurich) — analog generalist.

### Logística

- **John, Indira, Mitch** — logística general del programa.

---

## 16. Referencias clave

- Bukhari et al. (2025). *Low-Cost Sensing and Classification for Early Stress
  and Disease Detection in Avocado Plants.* arXiv 2508.13379. — Benchmark
  principal.
- Kassanos et al. — *Bio-impedance ASIC, 31 µW, 125 kHz, TSMC 0.18 µm.* —
  Precedente de chip.
- Sánchez-Cano et al. (2020). *Metabolt device.* Sensors. PMC7472036. —
  Análogo más cercano en suelo.
- Zhang et al. (2025). *Microfluidic Phytophthora zoospore impedance sensor.*
  Biosensors 15:131. PMC11940179. — Precedente de IS para Phytophthora
  (microfluídica, no suelo).
- Solís-García et al. (2021). *P. cinnamomi rhizosphere microbiome shifts.*
  Front. Microbiol. PMC7835518. — Base para framing de detección de anomalías.
- Dai et al. (2022). *RPA-LFD for Pcinn13739 gene.* PMC9452884. — Ground
  truth molecular para validación.
- Loewer et al. (2017). *Soil dielectric spectroscopy.* Geophys. J. Int. —
  Física de suelo en bandas de frecuencia.
- Comeau et al. (2024). *Long-term electrode stability.* Earth & Space Sci.
  — Riesgos de fouling y DC offset.
- Vergara et al. (2024). *VOC fingerprinting of Phytophthora.* Molecules
  29:1749. — Ilustra dificultad de especificidad.
- Kelleners et al. (2009). *Coil probe for in situ measurement of soil
  electrical impedance spectra.* Soil Sci Soc Am J.
- Yang et al. (2023). *Impedance-based detection of microbial biofilms.*
  Sensors and Actuators B.
- OpenFASOC AFE Chipathon 2024. — Precedente de ASIC en GF180MCU.
- IEEE Open Silicon Chips slide deck (Boris Murmann + John R. Long, 28 jun
  2024) — historial de PICO Chipathon 2021-2024.
- IEEE SSCS PICO Chronicles 2025 (IEEE Xplore document 11131441) — 2025
  launch with 360+ participants.

---

## 17. Cómo leer este documento según contexto

- **Si eres mentor PICO:** secciones 2, 3, 4, 9, 11, 13.
- **Si eres académico o reviewer paper:** secciones 6, 7, 8, 10, 13.2, 16.
- **Si eres colaborador potencial del Chipathon:** secciones 4, 9, 11, 15.

---

*Owner:* Ernest Darell Zermeño (chip design + operator's founder).
*Repo público:* github.com/Jefemaestro33/nopal-sense
*PICO Chipathon 2026:* Track B (Circuits for Sensors) + Track D (AI/LLM-assisted).
*Última actualización:* 8 mayo 2026.
