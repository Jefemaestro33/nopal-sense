# Nopal-Sense v1 — Frozen Specification

**Document status:** DRAFT (frozen target: 2026-05-08 chipathon kickoff)
**Version:** 0.2 (PDK reality alignment + 3-stage priority labels pending)
**Date:** 2026-04-18 (original) / 2026-05-08 (strategic clarifications)
**Owner:** Ernest Darell Zermeño Plascencia

Este documento es el **contrato técnico** entre el equipo de diseño y el mentor PICO.
Todo cambio post-freeze requiere revisión formal.

> 📝 **2026-05-13 Update — PDK reality reconciliada**:
> SP-TEC-002/003 (tape-out date + padring), SP-PWR-001/002/003 (voltage), SC-OUT-009 (LDO), y SP-TEC-004 (area) ya reflejan workshop slot 88-pin + 3.3V único. `EN_LDO` pin eliminado del pinout. Ver `PIN_ASSIGNMENT.md` para asignación funcional.
>
> **Priority labeling (P1/P2/P3) per requirement será agregado progresivamente** durante mayo-junio antes del Project Proposal Review (12 jun).
>
> Resoluciones técnicas 2026-05-13: **OQ-006 → B (10/30/100 kHz, bio-band specialist)** + **TIA range → 100 Ω – 30 kΩ con 3 gain levels (1×/10×/100×)** match al freq band (electrode+cable parasitic Z_C limita rango medible arriba de eso). Decisiones técnicas pendientes para mentor: OQ-001 (TIA topology), OQ-007 (DC offset cancellation), OQ-009 (VREF buffer PSRR).

---

## 0. Priority strategy (NEW 2026-05-08)

Para reducir bring-up risk del v1, los REQ-* se etiquetarán con priority labels:

- **[P1]** — Must-work bring-up gate. IS path + ADC + SPI + VREF + bandgap. Failure = no paper.
- **[P2]** — Firmware-debugged si borderline. Humidity readout, EC, MUX, auto-zero. Failure = degraded but useful chip.
- **[P3]** — Deferable a v1.1. Power switches, clock export, IRQ aggregator. Failure = bypass with commercial counterparts.

**Mapping a Stage research program**:
- Stage 1 (presence) → P1 IS path + ADC suficiente. v1 ready.
- Stage 2 (kingdom) → P1 + firmware updates. v1 ready.
- Stage 3 (species) → Requires v2 mask set.

Es decir: **el v1 chipathon es específicamente diseñado para validar Stages 1 y 2 con high probability.**

---

## 1. Scope

### 1.1 In-scope (v1 PICO 2026)

El chip Nopal-Sense v1 implementa:

**SC-IN-001:** Interfaces de sensor consolidadas (SPI, 1-Wire, pulse counter, ADC)
**SC-IN-002:** Impedance Spectroscopy a 3 frecuencias fijas en bio-band: **10 kHz, 30 kHz, 100 kHz** (OQ-006 resuelto 2026-05-13 → Opción B bio-centric)
**SC-IN-003:** Sleep controller autónomo con wake timer
**SC-IN-004:** Register bank 32×16-bit con acceso SPI slave
**SC-IN-005:** PUF simple basado en SRAM power-up state (chip ID únicamente)
**SC-IN-006:** 4 modos de operación con scheduler básico
**SC-IN-007:** Alert engine con threshold comparators
**SC-IN-008:** Connectivity bridges (12 specific external interfaces)
**SC-IN-009:** 4 architectural exports (VREF, CLK, power switches, INT aggregator)
**SC-IN-010:** CRC16 hardware para LoRa packet integrity

### 1.2 Out-of-scope (diferido a v2 o firmware ESP32)

**SC-OUT-001:** Scoring Phytophthora v3/v4 (stays en VPS para iteración)
**SC-OUT-002:** Fuzzy extractor PUF completo (v1 usa external ATECC608)
**SC-OUT-003:** FeRAM on-chip (v1 usa external FeRAM SPI)
**SC-OUT-004:** Tamper detection sofisticado (v1 usa reed switch input)
**SC-OUT-005:** Hardware I2C master (v1 usa bit-banged state machine)
**SC-OUT-006:** Secure boot (v1 usa firmware + ATECC608)
**SC-OUT-007:** ML accelerator (v1 delega a VPS)
**SC-OUT-008:** Barrido IS programable (v1 solo 3 frecuencias fijas)
**SC-OUT-009:** LDO 1.8V dual rail — eliminado por restricción PDK (v1 es 3.3V único, sin LDO externo).
**SC-OUT-010:** JTAG formal (v1 usa SPI debug mode)

### 1.3 Interfaces

**Chip se comunica con:**
- ESP32 host (vía SPI slave + GPIO interrupts)
- DS18B20 temperature sensor (vía 1-Wire)
- External FeRAM (vía SPI master, opcional)
- External ATECC608 (vía bit-banged I2C, opcional)
- Sensores analógicos (vía 8-ch ADC mux)
- Pulse sources: EC probe, rain gauge, anemómetro
- Impedance probes: electrodes A/B en suelo

---

## 2. Process and Technology

### 2.1 Manufacturing

**SP-TEC-001:** Proceso GlobalFoundries GF180MCU (180nm CMOS con HV option)
**SP-TEC-002:** Tape-out via PICO Chipathon 2026 shuttle (Final Submission TBD ~Sept 2026, post Final Chip Review Aug 28)
**SP-TEC-003:** Padring: workshop slot 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS, die 2935×2935 µm, core 2051×2051 µm)
**SP-TEC-004:** Active design area budget: ~3-4 mm² within the 2051×2051 µm core
**SP-TEC-005:** Metal layers: 5 (suficiente para digital + analog mixed)

### 2.2 Power

**SP-PWR-001:** VDD (single rail): 3.3V ± 10% (rango 2.97-3.63V). Analog y digital comparten rail; PDK gf180mcuD no ship 1.8V std cells nativos.
**SP-PWR-002:** I/O cells: 5V WR pads del workshop padring (operan a 3.3V con impacto en speed; permite interfacear directo con sensores 5V externos).
**SP-PWR-003:** I/O level: CMOS 3.3V compatible
**SP-PWR-004:** Sleep current (deep sleep, wake timer only): <1 µA typical, 3 µA max
**SP-PWR-005:** Active current (IS measurement, 100 ms burst): <2 mA typical, 3 mA max
**SP-PWR-006:** Startup time (power-on to operational): <10 ms

---

## 3. Functional Requirements

### 3.1 Impedance Spectroscopy (flagship)

**REQ-IS-001:** Chip shall generate sinusoidal excitation at 3 frequencies in bio-band: **10 kHz, 30 kHz, 100 kHz**
**REQ-IS-002:** Excitation amplitude: 100 mVpp ± 10% (configurable via register)
**REQ-IS-003:** Excitation DC offset: 0 V ± 10 mV (rail-to-rail centered)
**REQ-IS-004:** Frequency accuracy: ±1% from target
**REQ-IS-005:** Chip shall measure complex impedance Z(ω) = |Z| ∠ φ at each frequency
**REQ-IS-006:** Magnitude accuracy: ±3% of reading across dynamic range **100 Ω – 30 kΩ** (bounded by electrode + cable parasitic capacitance at top freq of 100 kHz — see ARCHITECTURE.md §6.1 for derivation). TIA implements 3 gain levels (1×, 10×, 100×) with auto-range.
**REQ-IS-007:** Phase accuracy: ±2° across dynamic range
**REQ-IS-008:** Measurement time per frequency: <30 ms
**REQ-IS-009:** Full 3-frequency sweep: <100 ms
**REQ-IS-010:** Results stored in Z_REGS[0..5] after sweep completes
**REQ-IS-011:** IS measurement triggerable via: register write, scheduler, or external SPI command
**REQ-IS-012:** Failed measurement (out-of-range, electrode fault) flagged in STATUS register

### 3.2 Sensor Interfaces

**REQ-SI-001:** SPI master shall support clock up to 5 MHz, modes 0-3
**REQ-SI-002:** 1-Wire master shall comply with Maxim DS18B20 protocol (standard speed)
**REQ-SI-003:** 1-Wire master shall support DS28E07 (64-bit ROM + 1 KB EEPROM) for probe IDs
**REQ-SI-004:** Pulse counter shall count inputs up to 1 MHz with 32-bit accumulator
**REQ-SI-005:** Pulse counter shall support debounce 0 / 1 µs / 10 µs / 100 µs configurable
**REQ-SI-006:** ADC shall be 14-bit SAR, INL <2 LSB, DNL <1 LSB
**REQ-SI-007:** ADC conversion time: <50 µs per sample (20 kSPS max)
**REQ-SI-008:** ADC input multiplexed across 8 channels + internal diagnostics
**REQ-SI-009:** Bit-banged I2C shall support 100 kHz standard speed, 7-bit addresses
**REQ-SI-010:** Power switching GPIOs (7×) shall drive up to 50 mA each, current-limited

### 3.3 Processing

**REQ-PR-001:** Calibration engine: y = a·x + b - α·(T - Tref), using Q8.8 fixed-point
**REQ-PR-002:** Moving average filter: window configurable 4/8/16, implemented as circular buffer
**REQ-PR-003:** Alert engine: 8 threshold comparators, each with configurable threshold and direction
**REQ-PR-004:** CRC-16: CCITT polynomial 0x1021, computed over SPI master output payload
**REQ-PR-005:** IS post-processing: magnitude via CORDIC, phase via arctan lookup

### 3.4 System Management

**REQ-SM-001:** Sleep controller shall support 5 modes (see §4. Operating Modes)
**REQ-SM-002:** Wake timer shall support periods: 1 min, 5 min, 15 min, 1 hr, 4 hr, 24 hr
**REQ-SM-003:** Wake timer accuracy: ±5% at room temperature (using 32 kHz RC oscillator)
**REQ-SM-004:** POR (power-on reset) shall hold chip in reset until VDD_D stable
**REQ-SM-005:** External reset (RST_N pin) shall force entire chip to sleep mode

### 3.5 Security

**REQ-SEC-001:** PUF shall produce 32-bit unique chip ID based on SRAM power-up state
**REQ-SEC-002:** PUF ID shall be readable after reset, stable across power cycles (>95% bit stability)
**REQ-SEC-003:** Register bank access may be protected by simple password (16-bit) in CONFIG mode
**REQ-SEC-004:** Tamper input (TAMPER pin) shall latch tamper flag that persists across sleep cycles

---

## 4. Operating Modes

### Mode 0: DEEP_SLEEP

- All blocks powered down except: wake timer, PUF retention, tamper detection
- Current target: <0.5 µA (typical), 1 µA (max)
- Wake sources: wake timer, external RST_N, SPI command from host (if SPI kept alive)
- Transition: to NORMAL on wake trigger

### Mode 1: NORMAL

- Active sensor reading and processing
- Duration: ~100 ms per cycle
- Actions per cycle:
  1. Enable external sensor power (GPIO_SW)
  2. Wait warm-up (configurable 0-500 ms)
  3. Read all sensors via ADC + 1-Wire + pulse counters
  4. Apply calibration + moving average
  5. Run alert comparators
  6. If IS enabled: run 3-frequency sweep
  7. Disable external sensors
  8. Return to DEEP_SLEEP (or ALERT if threshold crossed)
- Current: ~2 mA typical during active phase

### Mode 2: ALERT

- Triggered when alert comparator fires in NORMAL mode
- Assert INT_OUT pin to wake ESP32
- Continue measuring at higher frequency (every 1 min)
- ESP32 firmware decides when to return chip to NORMAL
- Current: ~500 µA average

### Mode 3: VALIDATION

- Triggered by external SPI command (typically once per 24 h)
- Performs extended IS measurement with averaging (e.g., 32 samples per frequency)
- Full diagnostic: check all sensors, run self-test
- Duration: up to 1 s
- Current: ~5 mA during validation

### Mode 4: DEBUG

- Entered via SPI opcode 0xDE
- All registers accessible regardless of lock state
- Continuous monitoring with maximum sample rate
- Used for benchtop debug, field troubleshooting
- Current: ~8 mA continuous

---

## 5. Register Map

**Access:** Via SPI slave, 16-bit data, 5-bit address.
**Endianness:** Big-endian on SPI (MSB first).

### 5.1 Status & Control (read/write)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x00 | CTRL | 16 | RW | 0x0000 | Bit 0: enable, bits 1-3: mode, bits 4-7: wake_period_sel, bits 8-15: reserved |
| 0x01 | STATUS | 16 | R | 0x0000 | Bit 0: ready, bit 1: measuring, bit 2: alert_active, bit 3: is_done, bit 4: error, bits 5-15: error_code |
| 0x02 | ALERT_FLAGS | 16 | RW | 0x0000 | 8 alert flags (one per comparator), write 1 to clear |
| 0x03 | TRIGGER | 16 | W | 0x0000 | Write commands: 0x0001=read_sensors, 0x0002=IS_sweep, 0x0004=self_test, 0x0008=clear_state |

### 5.2 Sensor Data (read-only)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x04 | H10_H20 | 16 | R | 0x0000 | Humidity 10cm (byte 0) + 20cm (byte 1), calibrated 0-255 |
| 0x05 | H30_TEMP | 16 | R | 0x0000 | Humidity 30cm (byte 0) + temperature (byte 1) |
| 0x06 | EC_FREQ | 16 | R | 0x0000 | EC frequency counter, 16-bit |
| 0x07 | BATTERY | 16 | R | 0x0000 | Battery voltage (byte 0), reserved (byte 1) |

### 5.3 Impedance Spectroscopy Results (read-only)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x08 | Z_MAG_10K | 16 | R | 0x0000 | |Z| at 10 kHz, Q8.8 format (Ω) |
| 0x09 | Z_PHASE_10K | 16 | R | 0x0000 | ∠Z at 10 kHz, Q4.12 format (radians) |
| 0x0A | Z_MAG_30K | 16 | R | 0x0000 | |Z| at 30 kHz (β-dispersion peak) |
| 0x0B | Z_PHASE_30K | 16 | R | 0x0000 | ∠Z at 30 kHz |
| 0x0C | Z_MAG_100K | 16 | R | 0x0000 | |Z| at 100 kHz |
| 0x0D | Z_PHASE_100K | 16 | R | 0x0000 | ∠Z at 100 kHz |

### 5.4 Calibration Configuration (read/write)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x0E | CAL_A | 16 | RW | 0x0100 | Calibration gain 'a', Q8.8 (default = 1.0) |
| 0x0F | CAL_B | 16 | RW | 0x0000 | Calibration offset 'b', signed Q8.8 |
| 0x10 | CAL_ALPHA | 16 | RW | 0x0000 | Temp coefficient, Q4.12 (default = 0.0) |
| 0x11 | CAL_TREF | 16 | RW | 0x1400 | Reference temperature, Q8.8 (default = 20.0°C) |

### 5.5 Thresholds (read/write)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x12 | TH_VPD | 16 | RW | 0x1800 | VPD threshold for irrigation alert |
| 0x13 | TH_HUM | 16 | RW | 0x3700 | Humidity saturation threshold |
| 0x14 | TH_TEMP | 16 | RW | 0x0500 | Temperature freeze threshold |
| 0x15 | TH_BAT | 16 | RW | 0x54F0 | Battery low threshold |

### 5.6 Scheduler Configuration (read/write)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x16 | SCHED_PERIOD | 16 | RW | 0x0000 | Wake period selector and validation period |
| 0x17 | SCHED_WARMUP | 16 | RW | 0x0064 | Warmup time for external sensors (ms) |
| 0x18 | GPIO_SW_CTRL | 16 | RW | 0x0000 | 7 power switches: bit N enables GPIO_SW[N] |

### 5.7 Diagnostic (read-only)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x19 | DIAG_ERR | 16 | R | 0x0000 | Error counters: IS_fail (byte 0), sensor_fail (byte 1) |
| 0x1A | DIAG_TIME | 16 | R | 0x0000 | Last measurement time (ms) |
| 0x1B | DIAG_CURR | 16 | R | 0x0000 | Approximate current consumption (µA) during last cycle |

### 5.8 Chip Identity (read-only)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x1C | PUF_ID_LO | 16 | R | varies | PUF bits 15-0 (unique per chip) |
| 0x1D | PUF_ID_HI | 16 | R | varies | PUF bits 31-16 |
| 0x1E | VERSION | 16 | R | 0x0100 | Hardware version: 0x0100 = v1.0 |

### 5.9 Debug (special)

| Addr | Name | Width | R/W | Reset | Description |
|------|------|-------|-----|-------|-------------|
| 0x1F | DEBUG | 16 | RW | 0x0000 | Accessible only in Mode 4 (Debug). Internal state exposure. |

---

## 6. SPI Slave Protocol

### 6.1 Physical layer

- 4-wire: SCK, MOSI, MISO, CS_N (active low)
- Mode: SPI mode 0 (CPOL=0, CPHA=0)
- Clock: up to 10 MHz
- Bit order: MSB first
- CS must be de-asserted between transactions

### 6.2 Frame format

```
Byte 0: Command byte
  Bit 7: R/W_N (1 = write, 0 = read)
  Bits 6-5: reserved (must be 0)
  Bits 4-0: register address (0x00 – 0x1F)

Bytes 1-2: Data (16-bit, MSB first)
  On read: chip outputs data on MISO
  On write: host sends new value on MOSI
```

### 6.3 Special opcodes

- `0xDE` (Debug mode enter): followed by 16-bit password
- `0xFF` (No-op): used for clock-out while reading

---

## 7. Timing Specifications

### 7.1 Power-on

- VDD_A rise time: 100 µs min (for stability)
- POR delay: 1 ms after VDD_D stable
- First SPI transaction allowed: 10 ms after VDD stable

### 7.2 Sleep/Wake

- DEEP_SLEEP entry: 100 µs max
- Wake timer wake-up: 10 µs (from internal 32 kHz)
- External RST_N wake: 1 ms
- NORMAL to ALERT transition: <10 µs (via interrupt)

### 7.3 IS measurement

- Settling time per frequency: 100 µs (10 kHz), 33 µs (30 kHz), 10 µs (100 kHz)
- Integration time: configurable 1-32 cycles per frequency
- Full sweep (3 frequencies, default settings): <100 ms

### 7.4 Sensor read

- ADC conversion: 50 µs per channel
- Full 8-channel scan: 400 µs
- DS18B20 temp conversion (12-bit): 750 ms (sensor-limited, not chip)
- EC frequency count: 100 ms integration

---

## 8. Environmental Specifications

**ENV-001:** Operating temperature: -10°C to 70°C
**ENV-002:** Storage temperature: -40°C to 85°C
**ENV-003:** Humidity: 0-95% RH non-condensing (package level)
**ENV-004:** ESD: HBM 2 kV min, CDM 500 V min per JEDEC
**ENV-005:** Latch-up: per JESD78 Class II Level A

---

## 9. Verification Criteria (sign-off gates)

### 9.1 RTL verification

**VER-RTL-001:** Line coverage ≥95% for all modules
**VER-RTL-002:** Branch coverage ≥90%
**VER-RTL-003:** FSM state coverage = 100%
**VER-RTL-004:** All REQ-* testable have passing cocotb test
**VER-RTL-005:** Golden model comparison: bit-exact match for >1000 random vectors per module

### 9.2 Analog verification

**VER-AMS-001:** DC operating point stable across corners (TT, FF, SS, FS, SF)
**VER-AMS-002:** Temperature sweep: -10°C to 70°C, all specs met
**VER-AMS-003:** Supply sweep: ±10% from nominal, all specs met
**VER-AMS-004:** Monte Carlo 100 runs: no spec violations in ±3σ
**VER-AMS-005:** IS accuracy validated on testbench with known impedances

### 9.3 Integration

**VER-INT-001:** Top-level simulation runs full day-in-the-life scenario
**VER-INT-002:** SPI host driver validates all register accesses
**VER-INT-003:** Power-aware simulation confirms current targets

### 9.4 Physical

**VER-PHY-001:** DRC clean (no violations)
**VER-PHY-002:** LVS clean (schematic matches layout)
**VER-PHY-003:** Antenna checks clean
**VER-PHY-004:** Timing closure at 1 MHz + 10% margin

---

## 10. Sign-off

This specification is considered FROZEN once:

- [ ] Mentor PICO reviews and approves (target: 2026-05-05)
- [ ] All REQ-* have acceptance criteria defined
- [ ] Golden model Python implements and validates all algorithms
- [ ] Block-level area and power budgets are feasible in GF180MCU

### Approvals

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Design Lead | Darell Plascencia | — | — |
| Mentor PICO | TBD (asignado 2026-05-01) | — | — |
| Reviewer | — | — | — |

---

## Appendix A: References

- GlobalFoundries GF180MCU PDK (open-source) — https://gf180mcu-pdk.readthedocs.io/
- PICO Chipathon 2026 — https://sscs.ieee.org/technical-committees/tc-ose/sscs-pico-design-contest/
- Kelleners et al. (2009) "Coil probe for in situ measurement of soil electrical impedance spectra", Soil Sci Soc Am J
- Yang et al. (2023) "Impedance-based detection of microbial biofilms", Sensors and Actuators B
- Randles J.E.B. (1947) "Kinetics of rapid electrode reactions", Discuss Faraday Soc

## Appendix B: Abbreviations

- IS — Impedance Spectroscopy
- VWC — Volumetric Water Content
- VPD — Vapor Pressure Deficit
- EC — Electrical Conductivity
- PUF — Physically Unclonable Function
- DDS — Direct Digital Synthesis
- TIA — Transimpedance Amplifier
- SAR — Successive Approximation Register (ADC type)
- POR — Power-On Reset
- CDC — Clock Domain Crossing
- INL/DNL — Integral/Differential Non-Linearity
