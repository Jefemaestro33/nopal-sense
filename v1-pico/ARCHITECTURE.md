# Nopal-Sense v1 — Architecture

**Scope:** Design rationale, block architecture, data flow, timing, and trade-off justifications.

This document explains **HOW** the chip achieves what `SPEC_FROZEN.md` requires.

---

## 1. System Context

### 1.1 Where the chip lives

```
                 ┌─────────────────────────────────────────────┐
                 │       HOST / CLOUD ANALYTICS LAYER          │
                 │  • Data aggregation                         │
                 │  • Firmware-managed measurement schedules   │
                 │  • Application-specific analytics           │
                 │  • Dashboard / alert delivery               │
                 └──────────────────▲──────────────────────────┘
                                    │ LoRaWAN / MQTT
                                    │
                 ┌──────────────────┴──────────────────────────┐
                 │       SENSOR NODE                           │
                 │                                             │
                 │   ┌──────────────────┐    ┌─────────────┐   │
                 │   │  ESP32 + LoRa    │◄──►│  Solar +    │   │
                 │   │  radio module    │    │  LiFePO4    │   │
                 │   └────────▲─────────┘    └─────────────┘   │
                 │            │ SPI slave                      │
                 │   ┌────────┴─────────┐                      │
                 │   │  Nopal-Sense v1  │  ←── this chip       │
                 │   │  ASIC (GF180)    │                      │
                 │   └──┬──┬──┬──┬──┬───┘                      │
                 │      │  │  │  │  │                          │
                 │  ┌───┘  │  │  │  └────┐                     │
                 │  │  ┌───┘  │  └───┐   │                     │
                 │  ▼  ▼      ▼      ▼   ▼                     │
                 │ [IS probe] [DS18B20] [EC] [ATECC608] [FeRAM]│
                 │ (probe)   (temp)    (freq)(secure) (buffer) │
                 │                                             │
                 └─────────────────────────────────────────────┘
```

### 1.2 Chip's role

Nopal-Sense v1 is a **mixed-signal sensor-control hub** that:

1. **Acquires** physical measurements through external probes and analog front-end blocks
2. **Consolidates** multiple sensor types through shared analog front-end
3. **Autonomously manages** power and duty cycling to maximize battery life
4. **Delivers structured data** to ESP32 via SPI slave interface

The chip is **NOT the brain** of the system. It is the measurement and control
engine. Application-specific decision-making remains in firmware or cloud
software.

---

## 2. Top-Level Block Diagram

```
    ┌────────────────────────────────────────────────────────────────────┐
    │                     NOPAL-SENSE v1 (die)                           │
    │                                                                    │
    │  ┌─────────────────────────────────────────────────────────────┐   │
    │  │               ANALOG SUBSYSTEM                              │   │
    │  │                                                             │   │
    │  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────────────┐   │   │
    │  │  │ DDS  │→→│ DAC  │→→│BUFFER│→→│ TIA  │→→│ MIXER I/Q    │   │   │
    │  │  └──────┘  └──────┘  └──────┘  └──────┘  └──────┬───────┘   │   │
    │  │      ▲                                           │           │   │
    │  │      │                                           ▼           │   │
    │  │      │  ┌─────────────┐     ┌────────────────┐  ┌─────────┐  │   │
    │  │      │  │ BANDGAP REF │ ←──→│ ADC 14-bit SAR │←─│ 8-ch MUX│  │   │
    │  │      │  └─────────────┘     └────────────────┘  └─────────┘  │   │
    │  │      │         │                    │                ▲       │   │
    │  │      │         │  VREF_OUT──────────┼────────────────┘       │   │
    │  │      │         │  (external)        │                        │   │
    │  │      │         │                    │                        │   │
    │  │      │         │         ┌──────────┴────────┐                │   │
    │  │      │         │         │  Guard rings      │                │   │
    │  │      │         │         │  + anti-aliasing  │                │   │
    │  │      │         │         └───────────────────┘                │   │
    │  │      │         │                                              │   │
    │  │      │                                                        │   │
    │  └──────┼────────────────────────────────────────────────────────┘   │
    │         │                                                            │
    │         │ (control)                                                  │
    │         │                                                            │
    │  ┌──────┴──────────────────────────────────────────────────────┐    │
    │  │               DIGITAL SUBSYSTEM                             │    │
    │  │                                                             │    │
    │  │  ┌───────────┐  ┌─────────┐  ┌─────────┐  ┌────────────┐    │    │
    │  │  │ Scheduler │→→│ IS FSM  │→→│Magnitude│→→│ Register   │    │    │
    │  │  │ FSM       │  │         │  │+ Phase  │  │ Bank       │    │    │
    │  │  └─────┬─────┘  └─────────┘  │ (CORDIC)│  │ 32×16-bit  │    │    │
    │  │        │                      └─────────┘  └──────▲─────┘    │    │
    │  │        │                                          │          │    │
    │  │        ├──→[1-Wire master]──→ OWIRE pin          │          │    │
    │  │        ├──→[SPI master]──→ SPI pins              │          │    │
    │  │        ├──→[bit-bang I2C]──→ I2C pins            │          │    │
    │  │        ├──→[Pulse counter ×2]←─ PULSE_IN pins    │          │    │
    │  │        ├──→[Calibration]──→ (to registers)       │          │    │
    │  │        ├──→[Moving Avg]──→ (to registers)        │          │    │
    │  │        ├──→[Alert engine]──→ INT_OUT pin         │          │    │
    │  │        └──→[CRC16]                               │          │    │
    │  │                                                  │          │    │
    │  │  ┌─────────┐   ┌──────────┐   ┌─────────────┐   │          │    │
    │  │  │  PUF    │──→│ Chip ID  │──→│ VERSION reg │───┘          │    │
    │  │  │ (SRAM)  │   │          │   └─────────────┘              │    │
    │  │  └─────────┘   └──────────┘                                │    │
    │  │                                                            │    │
    │  │                                  ┌──────────┐              │    │
    │  │                                  │ SPI slave│←──→ SPI pins │    │
    │  │                                  │ (to ESP32)│             │    │
    │  │                                  └──────────┘              │    │
    │  └────────────────────────────────────────────────────────────┘    │
    │                                                                    │
    │  ┌─────────────────────────────────────────────────────────────┐   │
    │  │               POWER / CLOCK SUBSYSTEM                       │   │
    │  │                                                             │   │
    │  │  [RC 1MHz main osc]──→ clock tree (gated per domain)        │   │
    │  │  [Ring 32kHz sleep]──→ always-on clock + wake timer         │   │
    │  │  [POR + BOD]        ──→ reset distribution                  │   │
    │  │  [Clock gating] ×12  ──→ per-subsystem gates                │   │
    │  │  [7× MOSFET switches] ──→ GPIO_SW[0..6] (external power)    │   │
    │  └─────────────────────────────────────────────────────────────┘   │
    └────────────────────────────────────────────────────────────────────┘
```

### 2.1 Three domains

The chip divides cleanly into 3 architectural domains:

| Domain | Purpose | Always-on? |
|--------|---------|------------|
| **Sleep domain** | Wake timer, PUF retention, tamper detection, reset | **Yes** |
| **Digital domain** | FSMs, SPI slave, register bank, processing | Gated (on in active modes) |
| **Analog domain** | IS block, ADC, MUX, signal conditioning | Gated (on only during measurement) |

---

## 3. Subsystem Architectures

### 3.1 Analog Front-End (IS block)

This is the flagship block. Detailed architecture:

```
                    ┌──────────────────────────────────────────────────┐
                    │              IMPEDANCE SPECTROSCOPY               │
                    │                                                  │
DIGITAL OSC ──┐     │    ┌──────┐   ┌──────┐   ┌────────────┐         │
(phase acc)   │     │    │ DDS  │──►│ DAC  │──►│ Buffer amp │         │
              └─────┼───►│table │   │ 10-b │   │ rail-to-   │──→ELEC_A│
                    │    └──────┘   └──────┘   │ rail       │         │
                    │                          └────────────┘         │
                    │                                                  │
                    │                  ┌───────────────────┐           │
                    │    ELEC_B ───────►│  TIA              │          │
                    │                  │  • Programmable   │          │
                    │                  │    gain (3 levels)│          │
                    │                  │  • Auto-range     │          │
                    │                  └─────────┬─────────┘          │
                    │                            │                     │
                    │                            ▼                     │
                    │                  ┌───────────────────┐           │
                    │                  │ Mixer I/Q          │          │
                    │                  │ ┌────────────────┐│          │
                    │                  │ │ I = V·cos(ωt)  ││          │
                    │                  │ │ Q = V·sin(ωt)  ││          │
                    │                  │ └────────────────┘│          │
                    │                  └──────┬─────┬──────┘           │
                    │                         │     │                   │
                    │                         ▼     ▼                   │
                    │                      ┌──────────┐                 │
                    │                      │ ADC 14-b │                 │
                    │                      └────┬─────┘                 │
                    │                           │                        │
                    │                           ▼                        │
                    │                  To Magnitude/Phase                │
                    │                  calculation (CORDIC)              │
                    └──────────────────────────────────────────────────┘
```

#### Key design decisions

**D-IS-001:** DDS implemented with phase accumulator + sine LUT (256 entries, quarter-wave stored)
- Saves area vs full cycle (1/4 table + symmetry)
- Phase resolution: 32-bit accumulator → <0.5 Hz resolution at 1 MHz

**D-IS-002:** DAC is 10-bit, not 12-bit
- 10-bit gives THD < 1% for sinusoidal excitation
- 12-bit doubles area for marginal benefit
- Justifies 0.2 mm² vs 0.4 mm²

**D-IS-003:** TIA gain programmable in 3 levels (1×, 10×, 100×)
- Auto-ranges during measurement
- Covers soil impedance range **100 Ω – 30 kΩ** at the operating bio-band (10-100 kHz)
- Upper bound set by electrode+cable parasitic capacitance (~200-500 pF) which dominates the AC path above ~30 kΩ at 100 kHz: Z_C = 1/(2π·f·C) ≈ 3 kΩ at 100 kHz, 500 pF → series with R_soil → effective measurement ceiling
- Lower bound by TIA noise floor + minimum useful gain (1×)

**D-IS-004:** I/Q mixer uses switching multipliers (not analog multipliers)
- Saves area
- Noise shaping with subsequent LPF
- Adequate for 14-bit final resolution

**D-IS-005:** Single ADC shared with sensor MUX
- Saves area (one ADC instead of two)
- Time-division: IS uses ADC during sweep, sensors use it otherwise
- Guard rings prevent crosstalk

### 3.2 Digital Processing Pipeline

```
  Raw sensor data
         │
         ▼
  ┌────────────┐
  │ Calibration│    y = a·x + b - α·(T - Tref)
  │ (Q8.8)     │    Fixed-point multiply + add
  └─────┬──────┘
        │
        ▼
  ┌────────────┐
  │ Moving Avg │    Circular buffer, shift-and-sum
  │ (4/8/16)   │    Window configurable
  └─────┬──────┘
        │
        ▼
  ┌────────────┐
  │  Alert     │    8 parallel comparators
  │  Engine    │    Each with threshold + direction
  └─────┬──────┘
        │
        ▼
  Registers + INT_OUT (if threshold crossed)
```

**D-DP-001:** All arithmetic in Q8.8 or Q4.12 fixed-point
- Avoids floating-point unit (large area)
- Adequate precision for sensor data (16-bit)
- Deterministic timing

**D-DP-002:** Moving average uses shift-right for divisions (power-of-2 windows)
- No divider needed
- Fast: 1 cycle per update

**D-DP-003:** Calibration uses DSP multiply-accumulate primitive
- Single unit shared across all channels
- Time-multiplexed

### 3.3 Scheduler FSM

```
                  ┌──────────────┐
                  │  DEEP_SLEEP  │
                  │  (default)   │
                  └──────┬───────┘
                         │ wake timer fires
                         │ OR SPI command
                         │ OR external INT
                         ▼
                  ┌──────────────┐
      ┌──────────│   NORMAL     │──────────┐
      │          │  (sensor     │          │
      │          │   read cycle)│          │
      │          └──────┬───────┘          │
      │                 │                  │
      │ threshold       │ cycle done       │
      │ crossed         │                  │
      │                 │                  │
      ▼                 ▼                  │
 ┌─────────┐      ┌──────────┐             │
 │  ALERT  │      │ (back to │             │
 │         │─────►│ SLEEP)   │             │
 └──┬──────┘      └──────────┘             │
    │                                      │
    │ ESP32 acks                           │
    │                                      │
    └──────────────────────────────────────┘

           (Parallel path)

  ┌──────────────┐                ┌──────────┐
  │  VALIDATION  │◄─── SPI cmd ───│ (any state)│
  │ (extensive   │                └──────────┘
  │  IS sweep)   │
  └──────────────┘

  ┌──────────────┐                ┌──────────┐
  │  DEBUG       │◄─── 0xDE opcode│ (any state)│
  │ (continuous) │                └──────────┘
  └──────────────┘
```

**D-SCH-001:** Scheduler implemented as single Mealy FSM with 5 states + transition matrix
**D-SCH-002:** Events: wake_timer, spi_cmd, alert_triggered, ack_received, reset, debug_opcode
**D-SCH-003:** Minimum cycle time: 100 ms (covers full sensor read + IS sweep)

### 3.4 Power Management

```
     ┌──────────────────────────────────────────────┐
     │            VDD (single rail, 3.3V)            │
     │                                               │
     │  ┌──────────────┐   ┌─────────────────────┐   │
     │  │ Sleep domain │   │ Analog domain       │   │
     │  │ always-on    │   │ gated per mode      │   │
     │  │ 0.5 µA       │   │ 2 mA when active    │   │
     │  └──────────────┘   └─────────────────────┘   │
     │                                               │
     │  ┌───────────────────────────────────────┐    │
     │  │ Digital domain                        │    │
     │  │ • Sleep: PUF retention, wake timer    │    │
     │  │   → 0.3 µA                            │    │
     │  │ • Active: full processing             │    │
     │  │   → 300 µA @ 1 MHz (5V std cells run  │    │
     │  │     at 3.3V — slower but functional)  │    │
     │  └───────────────────────────────────────┘    │
     └──────────────────────────────────────────────┘
```

**D-PWR-001:** Single voltage rail at 3.3 V. The gf180mcuD setup does not provide native 1.8 V standard cells.
- Original plan was VDD_D = 1.8V dual rail with external LDO — eliminated post-PDK-validation.
- Standard cells available are 5V databook (`gf180mcu_fd_sc_mcu7t5v0`); operate at 3.3V with reduced speed vs nominal 5V, but power benefit vs 5V operation still substantial.
- Analog domain at 3.3V — adequate dynamic range for IS block at 100 mVpp excitation.

**D-PWR-002:** Clock gating at subsystem granularity
- 12 independent gates (one per major block)
- Gates controlled by scheduler FSM
- Sleep mode gates everything except wake timer

**D-PWR-003:** GPIO_SW[0..6] are strong PMOS switches driven by register bits
- Each pad can drive up to 24 mA on-die; higher load currents require an external MOSFET.
- Allow chip to power external sensors on-demand
- Key enabler of <1 mA·h/day budget

---

## 4. Clock and Reset

### 4.1 Clock domains

| Domain | Source | Frequency | Always-on? | Used by |
|--------|--------|-----------|------------|---------|
| CLK_MAIN | Internal RC osc (calibrated) | 1 MHz ±5% | No (gated when sleep) | Digital logic, ADC |
| CLK_SLEEP | Ring osc | 32 kHz ±30% | **Yes** | Wake timer, tamper, PUF |
| CLK_IS | Derived from CLK_MAIN (PLL-less) | 10 kHz / 30 kHz / 100 kHz | Active during IS | DDS |

### 4.2 Clock domain crossings

Only 2 CDC interfaces:
- **CLK_SLEEP → CLK_MAIN:** wake signal from timer (double-flop synchronizer)
- **CLK_MAIN → CLK_SLEEP:** scheduler commands (handshake protocol)

All other signals stay within single domain.

### 4.3 Reset strategy

```
     POR (on VDD_D rise)
          │
          ├─────────────────────→ Sleep domain reset (async)
          │
          └─► reset synchronizer ─► Main digital reset (sync release)

     RST_N pin ─► filter ─► same path as POR
```

**D-RST-001:** Async assertion, synchronous de-assertion (standard practice)
**D-RST-002:** 10-cycle reset pulse minimum to ensure full propagation
**D-RST-003:** Reset extension: 1024 cycles of CLK_SLEEP after VDD stable (~30 ms)

---

## 5. Data Flow Scenarios

### 5.1 Scenario A: Normal sensor read cycle

```
  t=0:     Wake timer triggers → scheduler to NORMAL state
  t=0.1:   Turn on GPIO_SW for external sensors (ADS1115, EC probe)
  t=100:   Wait warmup (100 ms typical for analog sensors)
  t=100:   Start 1-Wire read of DS18B20 (750 ms total, runs in parallel)
  t=100:   ADC starts cycling through 8 channels (400 µs for full scan)
  t=100.5: EC pulse counter integrates over 100 ms
  t=200:   Integration complete, store in H10_H20, H30_TEMP, EC_FREQ, BATTERY regs
  t=200:   Apply calibration (10 µs)
  t=200:   Update moving average buffers
  t=200:   Run alert comparators
  t=200:   If IS enabled: start IS sweep
  t=300:   IS sweep complete (100 ms), store Z_MAG/Z_PHASE regs
  t=300:   Turn off GPIO_SW
  t=300:   Assert INT_OUT if any alert (ESP32 wakes)
  t=300:   Update STATUS register, return to DEEP_SLEEP
```

Total active time: 300 ms
Average current during cycle: ~1.5 mA × 300 ms = 450 µA·s per cycle
With 1-hour cycle period: 450 µA·s / 3600 s = 0.125 µA average (excluding sleep current)
Add sleep current (0.5 µA): total average ~0.7 µA

### 5.2 Scenario B: IS measurement (detailed)

```
  t=0:     IS FSM entered
  t=0:     Load frequency 1 (10 kHz) into DDS phase increment register
  t=0.1:   Turn on DAC, buffer, TIA
  t=0.6:   500 µs settling (10 kHz needs more cycles to stabilize electrode)
  t=0.6:   Start ADC sampling at 40 kSPS (4 samples per period at 10 kHz)
  t=3.8:   32 periods captured = 3.2 ms data
  t=3.8:   Run CORDIC for magnitude + phase → Z_MAG_10K, Z_PHASE_10K
  t=3.8:   Switch to frequency 2 (30 kHz)
  t=3.9:   100 µs settling
  t=3.9:   Sample ADC at 120 kSPS (4 samples per period at 30 kHz)
  t=5.0:   32 periods captured = ~1.07 ms data
  t=5.0:   Compute → Z_MAG_30K, Z_PHASE_30K
  t=5.0:   Switch to frequency 3 (100 kHz)
  t=5.02:  20 µs settling
  t=5.02:  Sample at 400 kSPS (4 samples per period at 100 kHz)
  t=5.34:  128 periods captured = 1.28 ms data
  t=5.34:  Compute → Z_MAG_100K, Z_PHASE_100K
  t=5.34:  IS FSM done, update STATUS
```

Total IS time: ~5-6 ms (well under the 100 ms spec). All three frequencies are inside the selected operating band (OQ-006 resolved 2026-05-13).

### 5.3 Scenario C: Alert triggered

```
  t=0:    Sensor read cycle running
  t=200:  Alert comparator fires (e.g., h20 > threshold)
  t=200:  Scheduler transitions NORMAL → ALERT state
  t=200:  Assert INT_OUT pin (ESP32 wake)
  t=200:  Do NOT return to sleep, stay in ALERT
  t=300:  Complete current cycle
  t=300:  Schedule faster cycle (1 min instead of 1 hr)
  t=60s:  Next cycle runs
  t=...:  Continue until ESP32 sends ack (register write to ALERT_FLAGS)
  t=ack:  Scheduler returns to NORMAL, next cycle uses normal period
```

---

## 6. Design Trade-offs (the honest story)

### 6.1 Why 3 fixed frequencies vs programmable sweep

**Pro fixed frequencies:**
- Smaller DDS (no divider, fixed phase increments in ROM)
- Easier verification (only 3 modes to test)
- Lower risk of tape-out failure
- Fits in 4-month PICO timeline

**Con:**
- Can't do research-grade sweeps
- Limited to known-good discriminatory frequencies

**Decision:** Acceptable for v1. v2 does programmable sweep.

### 6.2 Why 14-bit ADC vs 12-bit or 16-bit

**Pro 14-bit:**
- Balance of area and precision
- Sufficient for 3% IS accuracy spec
- Fits in ~0.4 mm² (vs 0.8 mm² for 16-bit)

**Con:**
- Not research-grade (16-bit would be)

**Decision:** 14-bit adequate; upgrade to 16-bit in v2 if needed.

### 6.3 Why shared ADC (IS + sensors) vs dedicated

**Pro shared:**
- Single ADC design (less verification)
- Saves 0.4 mm² area

**Con:**
- Time-division required (slightly slower overall)

**Decision:** Shared. IS and sensor reads never truly parallel in time.

### 6.4 Why RC oscillator vs crystal

**Pro internal RC:**
- No external crystal required (smaller BOM)
- Faster startup
- Tolerates environmental shock

**Con:**
- Only ±5% accuracy
- Drifts with temperature

**Decision:** Internal RC acceptable. For DDS we derive from same clock, so frequencies are relative (ratio is accurate even if absolute is off).

### 6.5 Why workshop slot 88-pin vs smaller pad ring

**Original SPEC said QFN-40.** PDK reality: the Chipathon workshop slot is 88-pin (60 analog + 20 bidir + 4 DVDD + 4 DVSS). This is the confirmed final pad ring.

**Pro 88-pin workshop slot:**
- Enough analog pads (60) for all consolidation features.
- 20 bidirectional digital pads for SPI, control, power switches, and interrupt aggregation.
- 4 separated power-domain pads (analog/digital VDD/VSS) for low-noise design.
- Supports a platform-ready sensor-control architecture.

**Con:**
- Larger die (2935×2935 µm vs the original ~2.7 mm² target), but the 2051×2051 µm core area remains sufficient.

**Decision:** workshop slot 88-pin confirmed. It enables the platform-ready architecture without pin-pressure compromises for v1.

Pin-count budget after trimming:
- 60 analog pads (IS electrodes + sensor inputs + VREF_OUT + analog controls)
- 20 digital pads (host SPI 4 + GPIO_SW 7 + INT 1 + 1-Wire 1 + I2C 2 + memory SPI 4 + pulse/tamper 1)
- Removed: EN_LDO, CLK_OUT, and PULSE_IN[1]. TAMPER is muxed with PULSE_IN.

---

## 7. Power Budget

### 7.1 Per-block active power (1 MHz)

| Block | Current (µA) | Notes |
|-------|--------------|-------|
| SPI slave | 50 | During transactions only |
| 1-Wire master | 100 | During probe read |
| ADC 14-bit SAR | 500 | During conversion (50 µs bursts) |
| Digital logic (processing) | 300 | During active processing |
| DDS + DAC | 400 | During IS measurement only |
| TIA + mixer | 800 | During IS measurement only |
| Reference bandgap | 50 | Always-on when active |
| I/O buffers | 100 | Depends on switching activity |

### 7.2 Sleep current breakdown

| Source | Current (nA) |
|--------|--------------|
| Wake timer (32 kHz RC + counter) | 200 |
| PUF retention (SRAM bits) | 100 |
| Leakage (standard digital) | 150 |
| Bandgap (always-on fraction) | 50 |
| **Total sleep** | **~500 nA** |

### 7.3 Cycle average (1 hr period)

- Active phase: 300 ms × 1.5 mA = 450 µA·s per cycle
- Sleep phase: 3599.7 s × 0.5 µA = 1800 µA·s per cycle (sleep dominates!)
- Per hour: 2250 µA·s = 0.625 µA·h average
- Per day: 15 µA·h

With 2500 mAh battery: 2500 mAh / 0.015 mA/h = 166,666 hours = 19 years!

In practice: self-discharge (~2%/month) is the floor. Battery life: **6-18 months depending on chemistry**.

---

## 8. Interfaces with External World

### 8.1 Chip to ESP32 (via SPI slave)

- ESP32 polls register 0x01 (STATUS) to check readiness
- ESP32 reads register 0x04-0x0D after `is_done` or `ready` flag
- ESP32 writes to 0x02 (ALERT_FLAGS) to clear alerts
- ESP32 writes to 0x03 (TRIGGER) to initiate measurements

### 8.2 Chip to external FeRAM (via SPI master, CS_MEM)

- Standard Cypress FM25V20A protocol (25-series SPI FRAM)
- Chip can buffer up to 256 KB of time-series data
- Write-through policy: every measurement appended

### 8.3 Chip to ATECC608 (via bit-banged I2C)

- 7-bit address 0x35 (default)
- Commands: GenKey, Sign, Verify, Random
- Used for: packet signing before LoRa TX

### 8.4 Chip to DS28E07 probe IDs (via 1-Wire, shared with DS18B20)

- Each probe has a DS28E07 with:
  - 64-bit unique ID
  - 1 KB EEPROM (for calibration coefficients)
- Chip reads IDs on boot, populates calibration registers accordingly

---

## 9. Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| TIA design is first attempt | High | High | Mentor with mixed-signal background; conservative design |
| IS path underperforms in GF180 process | Medium | High | Prior benchtop validation with commercial impedance reference + calibration samples |
| Clock accuracy insufficient for IS | Low | Medium | DDS ratio is deterministic; absolute drift doesn't affect Z(ω) ratios |
| Area overshoots 3 mm² | Medium | Medium | Area margin of 30% in budget; drop features if needed |
| Timing closure fails at 1 MHz | Low | Low | 1 MHz is easy for 180nm; retime if needed |
| Scheduler FSM has bugs | Medium | High | Formal verification (SymbiYosys) for FSM |
| External bridges don't integrate well | Low | Medium | Verify with breadboard before tape-out |

---

## 10. Open Questions (for mentor review)

- **OQ-001:** Should we add a second ADC dedicated to IS for true simultaneous readings?
- **OQ-002:** Is 32-bit PUF sufficient, or should we go to 64-bit for lower collision probability?
- **OQ-003:** Do we need brown-out detection? Trade-off: area vs reliability.
- **OQ-004:** Should scheduler support user-programmable wake periods, or fix to the 6 presets?
- **OQ-005:** Add dedicated test pins for analog monitor during debug?
- **OQ-006 (resolved 2026-05-13):** Final IS frequencies: **10 kHz / 30 kHz / 100 kHz**. EC and VWC can remain supported by external sensors depending on the test system.
- **OQ-007 (added 2026-05-07):** DC offset cancellation strategy: firmware auto-zero vs hardware AC coupling. Raw electrodes may present 50-280 mV typical DC offset.
- **OQ-008 (added 2026-05-07):** T-correction on-chip vs off-chip software. REQ-PR-001 linear Q8.8 does not capture Debye/Arrhenius behavior. Prefer off-chip correction unless mentor recommends otherwise.
- **OQ-009 (added 2026-05-07):** VREF_OUT buffer strategy. Exported 0.05% precision requires a dedicated buffer plus external compensation.

These are resolved in mentor meetings after the 2026-05-08 chipathon kickoff.

---

## 11. Modular Spine + Bring-Up Priority Strategy

To reduce bring-up risk, the chip blocks are organized into **3 priority
tiers**.

### Priority 1 (P1) — Must-work bring-up gate

These blocks define whether the chip is usable as a measurement platform:

- **Complete IS path**: DDS → DAC → Buffer → TIA → Mixer I/Q → LPF
- **ADC 14-bit SAR**
- **SPI slave** + register bank
- **VREF + bandgap reference**
- **POR + reset distribution**
- **CLK_MAIN RC oscillator** + sleep clock

Each P1 block should have standalone SPI-accessible test coverage for
post-silicon debug.

### Priority 2 (P2) — Firmware-debugged if borderline

If these blocks have minor issues, firmware can compensate or bypass them:

- **Humidity readout** (capacitive sensing channels)
- **EC measurement** (DC injection + readout)
- **ADC MUX 8-channel**
- **Auto-zero / DC offset cancellation** (OQ-007 implementation)
- **CRC16 hardware**
- **Pulse counter**

### Priority 3 (P3) — Deferable to v1.1

These are system-convenience and expansion features. Failure in v1 should not
block basic bring-up:

- **GPIO_SW programmable power switches**
- **External bridge chip-select handling**
- **INT aggregator**
- **Tamper detection**
- **PUF chip ID**
- **1-Wire master**
- **I2C bit-banged master**

### Bring-up sequence

1. Power-on test: power, POR, reset.
2. SPI communication: slave interface + register bank.
3. VERSION register read.
4. Single-channel ADC test.
5. VREF measurement.
6. DDS + DAC excitation test.
7. TIA + mixer receive-path test.
8. Full IS measurement loop.
9. P2 sensor-support blocks.
10. P3 exports and external bridges.

### Design philosophy

The public v1 target is a conservative measurement platform:

- keep raw observability for debug;
- expose enough registers for firmware-driven experiments;
- keep analog and digital assumptions explicit;
- defer high-level analytics to software;
- prefer testability over clever on-chip inference.

---

## See Also

- [`SPEC_FROZEN.md`](./SPEC_FROZEN.md) — Formal requirements
- [`PIN_ASSIGNMENT.md`](./PIN_ASSIGNMENT.md) — Physical pinout
- [`README.md`](./README.md) — Overview
