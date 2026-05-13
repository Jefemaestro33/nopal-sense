# Nopal-Sense v1 (PICO 2026)

**Chip para PICO Chipathon 2026 — tape-out ~Sept 2026 (post Final Chip Review Aug 28), chips en mano ~ene 2027.**

Filosofía: **Platform-ready, no minimum-viable.** v1 hace menos que v2, pero cada función diferida se apoya con bridges que hacen que v1 ya sea superior a cualquier nodo comercial.

---

## Resumen técnico

| Parámetro | Valor |
|-----------|-------|
| Proceso | GlobalFoundries gf180mcuD 180nm (variante D, open-source) |
| Dominio | Mixed-signal (digital + analog) |
| Padring | Workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS) |
| Die | 2935×2935 µm (core 2051×2051 µm, ~3-4 mm² active design area) |
| Consumo sleep | <1 µA target |
| Consumo activo (IS measurement) | <2 mA durante 100 ms |
| Voltaje | 3.3V único (PDK gf180mcuD sin 1.8V std cells nativos) |
| Clock principal | 1 MHz RC oscillator calibrado (±5%) |
| Clock sleep | 32 kHz ring oscillator (±30%, always-on) |
| Interface host | SPI slave a ESP32 (hasta 10 MHz) |

---

## Bloques incluidos

### Grupo A: Interfaces de sensor (0.69 mm²)

| Bloque | Área | Función |
|--------|------|---------|
| SPI slave | 0.02 mm² | Comunicación con ESP32 host |
| SPI master | 0.02 mm² | Lectura de sensores SPI externos (futuros) |
| 1-Wire master | 0.03 mm² | DS18B20 temperatura + DS28E07 probe IDs |
| Pulse counter × 2 | 0.02 mm² | EC probe frequency + opcional pluviómetro |
| ADC 14-bit SAR diferencial | 0.40 mm² | Shared precision, reemplaza ADS1115 externo |
| Analog MUX 8-canales con guard rings | 0.15 mm² | Entrada analógica multiplexada |
| Power switching (4 FETs configurables) | 0.05 mm² | Control power de sensores externos |

### Grupo B: Impedance Spectroscopy — función estrella (1.00 mm²)

| Bloque | Área | Función |
|--------|------|---------|
| DDS (3 frecuencias fijas: 10k, 30k, 100k Hz) | 0.15 mm² | Generador de sinusoidales digitales bio-band |
| DAC 10-bit | 0.20 mm² | Conversión a voltaje analógico |
| Electrode buffer/driver | 0.10 mm² | Maneja impedancia variable del suelo |
| TIA (Transimpedance Amplifier) con auto-range | 0.20 mm² | Convierte current → voltage |
| Mixer I/Q (quadrature demodulation) | 0.20 mm² | Extrae magnitud + fase |
| Reference bandgap | 0.15 mm² | Precision reference (exportada también) |

### Grupo C: Procesamiento digital (0.21 mm²)

| Bloque | Área | Función |
|--------|------|---------|
| Register bank (32 × 16-bit) | 0.05 mm² | Storage de mediciones + configuración |
| Fixed-point ALU (Q4.4 / Q8.8) | 0.05 mm² | Calibración + aritmética básica |
| Moving average filter (window 4/8/16) | 0.03 mm² | Signal conditioning |
| Alert engine (comparadores con thresholds) | 0.02 mm² | Threshold comparison → wake ESP32 |
| CRC16 engine | 0.01 mm² | Integridad de paquetes LoRa |
| IS post-processing (magnitud + fase) | 0.05 mm² | Cálculo final de Z(ω) |

### Grupo D: Sistema y energía (0.24 mm²)

| Bloque | Área | Función |
|--------|------|---------|
| Sleep controller | 0.02 mm² | Gestión de modos de energía |
| Wake timer autónomo (RC 32kHz) | 0.08 mm² | Despertar autónomo sin MCU |
| Clock management (main + sleep) | 0.05 mm² | Dual clock domain con CDC |
| Power-on reset + brown-out | 0.03 mm² | Startup determinístico |
| Scheduler básico (4 modos) | 0.03 mm² | Rutinas fijas pre-programadas |
| Simple PUF (SRAM-based, 32-bit ID) | 0.03 mm² | Chip identity (sin fuzzy extractor) |

### Grupo E: I/O

Padring proporcionado por el workshop slot del chipathon (no se cuenta en área de diseño activo). 88 pads + 4 corner cells. Ver `PIN_ASSIGNMENT.md` para el pad map detallado.

### Total estimado: ~3-4 mm² de diseño activo dentro del core 2051×2051 µm

---

## Pin assignment (workshop slot 88-pin)

El padring del chipathon es fijo y wirea un `chip_top.sv` inmutable al `chip_core.sv` (donde va tu diseño). Los puertos del chip_core están parametrizados por `SLOT_WORKSHOP` en `src/slot_defines.svh`:

- **clk + rst_n** — pads dedicados (no son parte de los 20 bidir)
- **input_in[0]** — 1 input pad CMOS extra (workaround Yosys zero-width-vector)
- **bidir[19:0]** — 20 pads bidireccionales (5V WR, 24 mA drive)
- **analog[59:0]** — 60 pads analog (5V WR `asig_5p0`, double diode protection, 10 mA)

Cada pad bidir tiene 7 señales de control (oe/cs/sl/ie/pu/pd + in/out). Ver `PIN_ASSIGNMENT.md` para la asignación funcional concreta a los 20 bidir + 60 analog disponibles, y el `chip_core.sv` template del workshop slot.

---

## Connectivity bridges (funciones diferidas pero accesibles)

Para cada función que cortamos del scope v1, hay un "bridge" que permite implementarla externamente mejor que en un nodo tradicional:

### Bridge 1: I2C master
- **v2 tendrá:** hardware I2C master a 400 kHz-1 MHz
- **v1 solución:** bit-banged state machine en digital logic, 2 pines dedicados
- **Resultado:** I2C funcional a 100 kHz, compatible con casi cualquier sensor I2C

### Bridge 2: FeRAM time-series
- **v2 tendrá:** FeRAM 64 KB integrada on-die
- **v1 solución:** SPI master con CS_MEM dedicado para FeRAM externa (Cypress FM25V20A, 256 KB, $4 USD)
- **Resultado:** buffer time-series de 256 KB en v1 (vs 64 KB proyectado para v2 on-die)

### Bridge 3: Fuzzy extractor PUF + secure crypto
- **v2 tendrá:** fuzzy extractor + secure boot + AES integrados
- **v1 solución:** PUF simple + ATECC608 externo via I2C
- **Resultado:** seguridad de nivel empresarial con $0.50 de BOM externo

### Bridge 4: Tamper detection
- **v2 tendrá:** detección sofisticada (voltage, frequency, PUF drift)
- **v1 solución:** pin TAMPER conectado a reed switch en caja del nodo
- **Resultado:** tamper básico funcional con $0.30 de hardware externo

### Bridge 5: Smart probe bus (plug-and-play)
- **v2 tendrá:** protocolo propio + IDs integrados en electrodos
- **v1 solución:** cada probe tiene DS28E07 ($0.30) en serie — chip lee ID por 1-Wire
- **Resultado:** plug-and-play real en v1 con chip diminuto en cada probe

### Bridge 6: Scheduler adaptativo
- **v2 tendrá:** state machine compleja para triggers dinámicos
- **v1 solución:** 4 modos fijos + 4 triggers configurables + firmware ESP32 coordina
- **Resultado:** scheduler adaptativo-by-proxy, funcional pero menos autónomo

### Bridge 7: Auto-diagnóstico hardware
- **v2 tendrá:** lógica de diagnóstico autónoma en silicio
- **v1 solución:** registros de diagnóstico (timing, current, impedance anomalies) + firmware ESP32 analiza
- **Resultado:** diagnóstico funcional con 50 ms de cómputo firmware

### Bridge 8: Barrido IS completo (100 Hz – 10 MHz)
- **v2 tendrá:** DDS programable con barrido fino
- **v1 solución:** 3 frecuencias fijas (10k, 30k, 100k Hz) en bio-band + firmware interpola con modelo Cole-Cole en banda ajustada
- **Resultado:** detección de biofilm demostrable; research limitado por 3 puntos

### Bridge 10: JTAG debug
- **v2 tendrá:** JTAG formal con boundary scan
- **v1 solución:** opcode SPI especial (0xDE) activa modo debug, acceso a registros internos
- **Resultado:** debug completo sin pines adicionales

### Bridge 11: ML accelerator
- **v2 tendrá:** aceleración on-chip de pattern matching
- **v1 solución:** datos transmitidos a VPS, ML corre en GPU
- **Resultado:** ML sin hardware especial, flexibilidad máxima

### Bridge 12: Secure boot
- **v2 tendrá:** secure boot completo en silicio
- **v1 solución:** PUF + ATECC608 + firmware ESP32 valida antes de operar
- **Resultado:** equivalente funcional para piloto

---

## Los 4 "regalos arquitectónicos"

Aunque v1 no integra todas las funciones, **exporta recursos internos** que benefician al nodo completo:

### 🎁 Regalo 1: VREF_OUT (pin 2)
Exporta la referencia bandgap interna (0.05% precisión).

Cualquier sensor externo que use esta referencia gana precisión de chip premium. Un sensor analógico genérico de $1 se vuelve comparable a uno premium de $20.

### 🎁 Regalo 2: CLK_OUT (pin 3)
Exporta el reloj calibrado de 1 MHz.

Sensores externos que requieren clock (algunos ADCs, chips RF) pueden usar este en lugar de osciladores externos. Reduce BOM + mejora coherencia de timing.

### 🎁 Regalo 3: 7 power switches programables (pines 21-27)
MOSFET switches controlados por registros del chip.

Permite apagar cada sensor externo individualmente. Da a sensores sin sleep modes sofisticados los beneficios del chip. Crítico para extender batería.

### 🎁 Regalo 4: INT_OUT (pin 10) — interrupt aggregator
Consolidación de todos los eventos internos en un solo interrupt al ESP32.

- Threshold crossings
- IS measurement complete
- Sensor errors
- Tamper detected
- Timer wake

ESP32 duerme profundo, despierta solo por 1 pin. Menos context switching = más batería.

---

## Modos de operación (scheduler básico)

| Modo | Trigger | Acciones | Consumo |
|------|---------|----------|---------|
| 0: Deep Sleep | Reset o por comando | Todo apagado excepto wake timer + PUF retention | ~0.5 µA |
| 1: Normal | Wake timer cada 1h | Lectura humedad + temp + IS + actualizar registros | 2 mA × 100 ms |
| 2: Alert | Threshold cruzado | Lectura inmediata + wake ESP32 via INT_OUT | 3 mA × 50 ms |
| 3: Validation | Comando del ESP32 (opcional cada 24h) | IS sweep + full sensor poll + diagnóstico | 5 mA × 500 ms |
| 4: Debug | SPI opcode 0xDE | Continuous monitoring, acceso a todos los registros | 8 mA continuo |

**Modo por defecto:** ciclo entre 0 (Deep Sleep) y 1 (Normal) con wake cada 1h. Duty cycle: ~0.003% (100 ms activo / 3600 s ciclo).

**Consumo promedio estimado:** 1-2 µA.

---

## Timeline de desarrollo (13 semanas antes de onboarding PICO)

```
ABRIL 18-20 (3 días):   Spec freeze completa, sign-off
ABRIL 21-28 (1 semana): Golden model Python completo + validación
ABRIL 29 - MAYO 1:       Pitch preparation para mentor
MAYO 1:                  Onboarding PICO (mentor assignment)
MAYO 2 - JUNIO 15:       RTL design + verification (digital blocks)
JUNIO 16 - JULIO 31:     Analog block design con mentor (IS, ADC, TIA)
AGOSTO 1-15:             Integration + top-level verification
AGOSTO 16-31:            Layout + DRC/LVS
SEPTIEMBRE 1-15:         Layout finalization + timing closure
SEPTIEMBRE 16-30:        Tape-out submission
OCTUBRE 2026:            Fab start (GlobalFoundries)
ENERO 2027:              Chips en mano
```

---

## Verificación

### Estrategia
Cada bloque se verifica contra el **golden model en Python** ([`./sim/golden_model.py`](./sim/golden_model.py)).

### Tools
- **Simulación digital:** Icarus Verilog + cocotb
- **Simulación analógica:** Cadence Spectre (provisto por mentor PICO)
- **Formal verification:** SymbiYosys (para módulos críticos: sleep_ctrl, PUF)
- **Mixed-signal:** Spectre AMS Designer

### Coverage targets
- Line coverage: >95%
- Branch coverage: >90%
- FSM state coverage: 100%
- Toggle coverage: >90%

### Test vectors
- 1000+ vectors por módulo digital
- Process corners (FF, SS, TT, FS, SF) para analog
- Temperature sweeps: -10°C a 70°C
- Voltage sweeps: 1.6V-2.0V core, 3.0V-3.6V I/O
- Monte Carlo: 1000 runs para mismatch analysis

---

## Riesgos técnicos y mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|-----------|
| Diseño analógico (TIA, mixer) es primera experiencia | Alta | Alto | Mentor PICO con background mixed-signal (solicitar explícitamente) |
| Timing closure en analog blocks difícil | Media | Alto | Márgenes conservadores, corners analysis temprano |
| PUF reliability baja sin fuzzy extractor | Alta | Bajo | Solo usar PUF como ID, no para crypto |
| IS no detecta biofilm como hipotetizamos | Media | Medio | Validación prior con equipo de laboratorio antes de tape-out |
| Scope creep hacia v2 features | Alta | Alto | Congelar spec v1 en abril 30, disciplina estricta |
| Mixed-signal verification subestimada | Alta | Medio | Allocar 30% del tiempo de diseño a verification |

---

## Validación previa al tape-out (antes de Final Chip Review Aug 28)

Mini-protocolo para reducir riesgo:

1. **Mes 5 (junio 2026):** Usando kit comercial de IS (AD5933 + electrodos + Arduino), hacer pilot scientific validation:
   - Medir Z(ω) en muestras de Andisol sin/con Phytophthora conocida
   - Identificar frecuencias discriminatorias
   - Refinar expectativas para v1

2. **Mes 6-7 (julio-agosto 2026):** Validar golden model contra datos reales:
   - Extraer features de Z(ω) de medidas reales
   - Confirmar que clasifican correctamente healthy vs infected
   - Si no, ajustar spec antes de tape-out

3. **Mes 8 (agosto 2026):** Design review formal con mentor:
   - ¿Las 3 frecuencias elegidas son óptimas?
   - ¿El rango dinámico del TIA es adecuado?
   - ¿La resolución del ADC es suficiente?

---

## Criterios de éxito

### Técnicos
- [ ] Tape-out entregado a tiempo (~Sept 2026, post FCR Aug 28)
- [ ] Chips recibidos y power-on (enero 2027)
- [ ] SPI communication funcional
- [ ] IS measurement produce datos interpretables
- [ ] Sleep mode consume <2 µA (stretch goal: <1 µA)
- [ ] Dataset IS + qPCR pareado generado (febrero-julio 2027)

### Científicos
- [ ] Paper submitido a venue IEEE (workshop o companion paper)
- [ ] Correlación IS vs qPCR lab publicable (target R² > 0.5)

### Estratégicos
- [ ] Credencial "chip mexicano para agricultura" establecida
- [ ] Lecciones claras para v2 spec
- [ ] Al menos 1 productor piloto con chip desplegado (even bench test)

---

## Archivos (pendientes de creación)

Pre-mayo 2026:
- [ ] `SPEC_FROZEN.md` — Especificación congelada formal
- [ ] `ARCHITECTURE.md` — Block diagram + data flow + timing
- [ ] `GOLDEN_MODEL.md` — Documentación del modelo Python
- [ ] `PIN_ASSIGNMENT.md` — Pad map workshop slot 88-pin
- [ ] `POWER_BUDGET.xlsx` — Consumo estimado por modo
- [ ] `AREA_BUDGET.xlsx` — Área estimada por bloque

Post-mayo 2026 (con mentor):
- [ ] `rtl/` — Verilog de todos los módulos
- [ ] `tb/` — Testbenches cocotb
- [ ] `analog/` — Schematics y layouts de bloques analógicos
- [ ] `layout/` — GDS final + DRC/LVS reports

---

## Siguiente paso inmediato

**Antes del 1 de mayo (onboarding PICO):**

1. Crear `SPEC_FROZEN.md` con todos los detalles de esta README formalizados
2. Completar golden model Python con:
   - Modelo físico del suelo (circuito Randles)
   - Simulación de Z(ω) para soil wet/dry/infected
   - Validación contra literatura (Kelleners 2009, Yang 2023)
3. Armar `MENTOR_BRIEFING.md` — 1 página:
   - Estado actual
   - Visión v1
   - Riesgos identificados
   - Preguntas específicas para mentor

Con esto llegas al onboarding preparado. Top 10% de equipos PICO.
