# Nopal-Sense v1 — Pin Assignment

**Package:** QFN-40 (6×6 mm, 0.5 mm pitch, exposed die paddle)
**Document:** Physical interface specification + PCB layout guidelines.

This document defines how the chip electrically connects to the PCB and to external components.

---

## 1. Package Specifications

### 1.1 QFN-40 mechanical

```
              6.00 mm
           ├─────────────┤
           ╱──────────────╲      ┐
          │  10       11   │     │
          │   •       •    │     │
          │                │     │
          │     ┌──────┐   │     │
          │     │      │   │   6.00 mm
     9 •  │     │ DIE  │   │  • 12
          │     │      │   │     │
          │     └──────┘   │     │
          │                │     │
          │   •       •    │     │
          │  40        20  │     │
           ╲──────────────╱      ┘
                  │
                  │
           ┌──────┴──────┐
           │  Exposed    │
           │  die pad    │  3.5 × 3.5 mm
           │ (GND tie)   │
           └─────────────┘
```

### 1.2 Key parameters

| Parameter | Value |
|-----------|-------|
| Package type | QFN (Quad Flat No-leads) |
| Pin count | 40 |
| Body size | 6.0 × 6.0 mm |
| Lead pitch | 0.5 mm |
| Lead width | 0.25 mm |
| Exposed pad | 3.5 × 3.5 mm (must tie to GND) |
| Package height | 0.9 mm max |
| Thermal resistance (θJA) | ~30°C/W (with pad soldered to GND plane) |
| Weight | ~0.1 g |

### 1.3 Pin numbering

- Pin 1 marked with corner dot or pin indicator on top
- Numbering: counterclockwise from pin 1
- Top-left corner = pin 1 (when viewed from above)
- Pins 1-10 on left, 11-20 on bottom, 21-30 on right, 31-40 on top

---

## 2. Pin Diagram (top view)

```
                 (TOP VIEW, looking down at package)

                    ┌─────────────────────────┐
                    │   31  32  33  34  35    │
                    │   ▲    ▲   ▲   ▲   ▲    │
                    │                         │
      10 ◀──────────┤                         ├──────────▶ 36
       9 ◀──────────┤                         ├──────────▶ 37
       8 ◀──────────┤                         ├──────────▶ 38
       7 ◀──────────┤     Nopal-Sense v1      ├──────────▶ 39
       6 ◀──────────┤         QFN-40          ├──────────▶ 40
       5 ◀──────────┤       GF180MCU          ├──────────▶  1
       4 ◀──────────┤                         ├──────────▶  2
       3 ◀──────────┤                         ├──────────▶  3
       2 ◀──────────┤                         ├──────────▶  4
       1 ◀──────────┤                         ├──────────▶  5
                    │                         │
                    │   ▼    ▼   ▼   ▼   ▼    │
                    │   20  19  18  17  16    │
                    └─────────────────────────┘

    (Visual is schematic; actual pin layout goes clockwise
     around perimeter, with pin 1 at top-left corner marker)
```

---

## 3. Complete Pin Table

### 3.1 Pin-by-pin specification

| Pin | Name | Type | Direction | Voltage domain | Drive / Load | Function |
|-----|------|------|-----------|----------------|--------------|----------|
| 1 | VDD_A | Power | In | 3.3V | 50 mA max | Analog supply |
| 2 | VREF_OUT | Analog | Out | 3.3V | 1 mA | 🎁 Precision reference (1.2V ±0.05%) |
| 3 | CLK_OUT | Digital | Out | 3.3V CMOS | 4 mA | 🎁 Clock output (1 MHz) |
| 4 | VDD_D | Power | In | 1.8V | 20 mA max | Digital core supply (external LDO) |
| 5 | GND_D | Ground | — | 0V | — | Digital ground |
| 6 | MOSI_S | Digital | In | 3.3V CMOS | — | SPI slave — data in (from ESP32) |
| 7 | MISO_S | Digital | Out | 3.3V CMOS | 4 mA | SPI slave — data out (to ESP32) |
| 8 | SCK_S | Digital | In | 3.3V CMOS | — | SPI slave — clock (from ESP32) |
| 9 | CS_S | Digital | In | 3.3V CMOS, active low | — | SPI slave — chip select |
| 10 | INT_OUT | Digital | Out | 3.3V CMOS, active low | 8 mA | 🎁 Interrupt aggregator (wakes ESP32) |
| 11 | RST_N | Digital | In | 3.3V CMOS, active low | Schmitt trigger, pull-up 100kΩ | External reset |
| 12 | OWIRE | Digital | Bidir, open-drain | 3.3V | 12 mA sink | 1-Wire master (DS18B20 + DS28E07) |
| 13 | I2C_SDA | Digital | Bidir, open-drain | 3.3V | 4 mA sink | Bit-banged I2C data (ATECC608) |
| 14 | I2C_SCL | Digital | Out, open-drain | 3.3V | 4 mA sink | Bit-banged I2C clock |
| 15 | MOSI | Digital | Out | 3.3V CMOS | 4 mA | SPI master data out (FeRAM) |
| 16 | MISO | Digital | In | 3.3V CMOS | — | SPI master data in |
| 17 | SCK | Digital | Out | 3.3V CMOS | 4 mA | SPI master clock |
| 18 | CS_MEM | Digital | Out, active low | 3.3V CMOS | 4 mA | Chip select for external FeRAM |
| 19 | TAMPER | Digital | In | 3.3V CMOS | Schmitt trigger, pull-up | Tamper detection (reed switch) |
| 20 | EN_LDO | Digital | Out | 3.3V CMOS | 4 mA | Enable pin for external 1.8V LDO |
| 21 | GPIO_SW[1] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch for external sensor |
| 22 | GPIO_SW[2] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 23 | GPIO_SW[3] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 24 | GPIO_SW[4] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 25 | GPIO_SW[5] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 26 | GPIO_SW[6] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 27 | GPIO_SW[7] | Digital | Out | 3.3V | 50 mA sink/source | 🎁 Power switch |
| 28 | PULSE_IN[0] | Digital | In | 3.3V CMOS | Schmitt trigger | Pulse counter (EC probe) |
| 29 | PULSE_IN[1] | Digital | In | 3.3V CMOS | Schmitt trigger | Pulse counter (rain/wind) |
| 30 | ADC_IN[7] | Analog | In | 0-3.3V | High-Z (>10 MΩ) | ADC channel 7 |
| 31 | ADC_IN[6] | Analog | In | 0-3.3V | High-Z | ADC channel 6 |
| 32 | ADC_IN[5] | Analog | In | 0-3.3V | High-Z | ADC channel 5 |
| 33 | ADC_IN[4] | Analog | In | 0-3.3V | High-Z | ADC channel 4 |
| 34 | ADC_IN[3] | Analog | In | 0-3.3V | High-Z | ADC channel 3 |
| 35 | ADC_IN[2] | Analog | In | 0-3.3V | High-Z | ADC channel 2 |
| 36 | ADC_IN[1] | Analog | In | 0-3.3V | High-Z | ADC channel 1 |
| 37 | ADC_IN[0] | Analog | In | 0-3.3V | High-Z | ADC channel 0 |
| 38 | ELEC_B | Analog | Bidir | 0-3.3V | Sense input | IS electrode B (sense) |
| 39 | ELEC_A | Analog | Bidir | 0-3.3V | Drive output, 10 mA | IS electrode A (drive) |
| 40 | GND_A | Ground | — | 0V | — | Analog ground |
| EP | GND (exposed pad) | Ground | — | 0V | — | Thermal + primary GND |

### 3.2 Pin summary by category

| Category | Count | Pins |
|----------|-------|------|
| Power / Ground | 4 | VDD_A, GND_A, VDD_D, GND_D |
| Exposed paddle (GND) | 1 | EP |
| SPI slave (host) | 4 | MOSI_S, MISO_S, SCK_S, CS_S |
| SPI master | 4 | MOSI, MISO, SCK, CS_MEM |
| 1-Wire | 1 | OWIRE |
| I2C (bit-bang) | 2 | I2C_SDA, I2C_SCL |
| ADC analog inputs | 8 | ADC_IN[0..7] |
| IS electrodes | 2 | ELEC_A, ELEC_B |
| Pulse inputs | 2 | PULSE_IN[0..1] |
| GPIO power switches (regalo) | 7 | GPIO_SW[1..7] |
| Control / status | 4 | RST_N, INT_OUT, TAMPER, EN_LDO |
| Architectural exports (regalos) | 2 | VREF_OUT, CLK_OUT |
| **Total** | **40** | + exposed pad |

---

## 4. Electrical Specifications

### 4.1 Absolute maximum ratings

| Parameter | Min | Max | Unit |
|-----------|-----|-----|------|
| VDD_A | -0.3 | 3.6 | V |
| VDD_D | -0.3 | 2.0 | V |
| Voltage on any digital I/O | -0.3 | VDD_A + 0.3 | V |
| Voltage on analog input | -0.3 | VDD_A + 0.3 | V |
| Storage temperature | -40 | 85 | °C |
| Junction temperature | — | 125 | °C |
| ESD (HBM) | 2000 | — | V |
| ESD (CDM) | 500 | — | V |
| Latch-up current | 100 | — | mA |

**Warning:** Exceeding these ratings may cause permanent damage. Operating near absolute max may reduce lifetime.

### 4.2 Recommended operating conditions

| Parameter | Min | Typ | Max | Unit |
|-----------|-----|-----|-----|------|
| VDD_A | 3.00 | 3.30 | 3.60 | V |
| VDD_D | 1.62 | 1.80 | 1.98 | V |
| Operating temperature | -10 | 25 | 70 | °C |
| Input low voltage (VIL) | — | — | 0.3 × VDD_A | V |
| Input high voltage (VIH) | 0.7 × VDD_A | — | — | V |
| Output low voltage (VOL) @ 4 mA | — | — | 0.4 | V |
| Output high voltage (VOH) @ 4 mA | VDD_A - 0.4 | — | — | V |

### 4.3 Current specifications

| Mode | Typical | Max |
|------|---------|-----|
| DEEP_SLEEP | 0.5 µA | 3 µA |
| NORMAL (active 300 ms) | 1.5 mA | 3 mA |
| ALERT | 0.5 mA avg | 1 mA |
| VALIDATION | 5 mA | 8 mA |
| DEBUG | 8 mA | 12 mA |

### 4.4 I/O timing

| Parameter | Min | Max | Notes |
|-----------|-----|-----|-------|
| SPI slave clock | — | 10 MHz | Up to 10 MHz supported |
| Setup time (MOSI to SCK) | 5 ns | — | |
| Hold time (MOSI after SCK) | 5 ns | — | |
| Clock-to-out (SCK to MISO) | — | 15 ns | |
| 1-Wire timing | Per Maxim DS18B20 spec | | |
| I2C timing | Per I2C standard 100 kHz | | |

---

## 5. PCB Layout Guidelines

### 5.1 Ground plane strategy

```
     ╔════════════════════════════════════════╗
     ║   PCB TOP VIEW                         ║
     ║                                        ║
     ║   ┌────────────────┐                   ║
     ║   │                │     DIGITAL       ║
     ║   │  Nopal-Sense   │     (ESP32, LoRa) ║
     ║   │  ASIC          │                   ║
     ║   │                │                   ║
     ║   └─┬────────────┬─┘                   ║
     ║     │            │                     ║
     ║     │            │                     ║
     ║     │ ANALOG     │ IS probe            ║
     ║     │ sensors    │ cable               ║
     ║     │            │                     ║
     ╚═════╪════════════╪═══════════════════╝
           │            │
           ▼            ▼
       (stellar GND)   (separate analog GND,
                        tied to digital GND
                        at single point near
                        chip's GND_A pin)
```

**Layout guidelines:**

- **GL-001:** Single-point GND star topology, joined at chip's exposed pad
- **GL-002:** Separate GND plane zones for digital and analog sides of PCB
- **GL-003:** Exposed pad MUST be soldered to PCB GND for thermal + electrical
- **GL-004:** Do not route signals UNDER the chip (use opposite layer)

### 5.2 Power decoupling

| Pin | Required capacitors |
|-----|---------------------|
| VDD_A (pin 1) | 100 nF + 10 µF, close to pin |
| VDD_D (pin 4) | 100 nF + 1 µF, close to pin |
| VREF_OUT (pin 2) | 100 nF + 1 µF (low-ESR), output bypass |

**GL-005:** Decoupling caps within 5 mm of respective VDD pin
**GL-006:** Use X7R or C0G dielectric for accuracy (not Y5V)

### 5.3 Analog signal routing

- **GL-007:** ELEC_A, ELEC_B traces: minimize length, use guard traces tied to GND_A
- **GL-008:** ADC inputs: low-ESR RC filters (100 Ω + 100 nF) close to pins
- **GL-009:** Avoid crossing digital signals under analog traces
- **GL-010:** Keep IS electrode cable <2m to minimize parasitic capacitance

### 5.4 Clock routing (CLK_OUT)

- **GL-011:** CLK_OUT trace ≤50 mm, series termination (33 Ω)
- **GL-012:** Do not fan out CLK_OUT to more than 2 loads without buffer

### 5.5 Reset and power-up

- **GL-013:** RST_N: 10 kΩ pull-up + 100 nF to GND (time constant ~1 ms)
- **GL-014:** Power sequencing: VDD_A rises first, then VDD_D (or simultaneous OK)
- **GL-015:** If using external LDO controlled by EN_LDO: add 10 µF output cap

### 5.6 ESD protection (external)

For cables going outside the enclosure (sensor probes, electrodes):

- **GL-016:** Add TVS diodes (e.g., SRV05-4) on cable entry
- **GL-017:** Ferrite beads on power lines to sensors
- **GL-018:** Internal chip ESD handles direct 2 kV HBM events, external TVS covers larger

---

## 6. Typical Application Circuit

```
                  VDD_A (3.3V from LiFePO4 + LDO)
                        │
          ┌─────────────┼──────────────────────────┐
          │             │                          │
         10µF          100nF                       │
          │             │                          │
          │             │                          │
         ─┴──           ├────────┐                 │
        (GND_A)         │        │                 │
                        │      [Chip Pin 1: VDD_A] │
                        │                          │
                        │                          │
          ┌─────────────┴──Nopal-Sense v1──────┐   │
          │                                    │   │
          │  Pin 4 (VDD_D) ←── 1.8V            │   │
          │                  from external LDO │   │
          │                                    │   │
          │  Pin 5 (GND_D) ──→ GND             │   │
          │  Pin 40 (GND_A) ──→ GND            │   │
          │  Exposed pad ──→ GND (via vias)    │   │
          │                                    │   │
          │  Pin 6-9 (SPI slave) ──→ ESP32     │   │
          │  Pin 10 (INT_OUT)    ──→ ESP32     │   │
          │  Pin 11 (RST_N)      ──→ ESP32     │   │
          │                                    │   │
          │  Pin 12 (OWIRE) ──→ DS18B20 + probe│   │
          │                      ID chips      │   │
          │                                    │   │
          │  Pin 13-14 (I2C) ──→ ATECC608      │   │
          │                                    │   │
          │  Pin 18 (CS_MEM) ──→ external FeRAM│   │
          │  Pin 15-17 (SPI master) ──→ FeRAM  │   │
          │                                    │   │
          │  Pin 19 (TAMPER) ──→ reed switch   │   │
          │                                    │   │
          │  Pin 21-27 (GPIO_SW) ──→ PMOS      │   │
          │                        switches    │   │
          │                        (external   │   │
          │                         sensors    │   │
          │                         power)     │   │
          │                                    │   │
          │  Pin 38-39 (ELEC_A/B) ──→ IS probe│   │
          │                             (inox   │   │
          │                              pines) │   │
          │                                    │   │
          └────────────────────────────────────┘
```

---

## 7. Bond Diagram (die to package)

The chip die is approximately 1.6 × 1.7 mm in GF180MCU (after pad ring).

### 7.1 Pad placement guidelines

- I/O pads around perimeter of die, 60 µm pitch (typical GF180 pad library)
- Analog pads isolated on one side (e.g., south side of die)
- Digital I/O on opposite sides
- Power pads distributed on all 4 sides for IR drop mitigation
- ESD protection cells per PDK standard

### 7.2 Die-to-package bonding

- Wire bonds: gold (standard for QFN)
- Bond wire length: <2 mm typical
- Downset: minimize (flat package)

---

## 8. Thermal Considerations

### 8.1 Power dissipation estimate

Worst-case: DEBUG mode @ 12 mA × 3.3V = 39.6 mW.
Typical: NORMAL mode average ~5 mW.

### 8.2 Temperature rise

With θJA ≈ 30°C/W:
- At 40 mW: ΔT = 40 × 0.030 = 1.2°C above ambient
- Negligible for this design.

Exposed pad is primary thermal path. Ensure good solder joint.

---

## 9. PCB Footprint

### 9.1 Recommended pattern

- QFN-40 6×6 mm 0.5 mm pitch — standard footprint
- Pad size: 0.25 mm × 0.6 mm
- Center thermal pad: 3.5 × 3.5 mm with 9-16 vias to inner GND layer
- Solder mask opening: pad + 50 µm expansion
- Stencil design: 80% coverage on thermal pad (avoid void from full solder)

### 9.2 Reference layout files

(To be generated in KiCad when PCB design starts for v1 node)

---

## 10. Ordering & Availability

### 10.1 Sample quantities (from PICO)

- Chips fabricated: typically 10-40 dies per team (from GF180MCU shuttle)
- Packaging: bare dies OR wire-bonded QFN (if PICO provides; otherwise external service)
- Cost per chip to team: $0 (IEEE pays fabrication)

### 10.2 Post-PICO availability

For additional chips:
- wafer.space in SKY130 (130nm): $7K USD for 1000 dies
- ChipFoundry.io chipIgnite in SKY130: $14.95K for 100 QFN
- Custom respin via wafer.space in GF180: similar cost

For v2 commercial:
- Target foundry: GF 130nm or IHP SG13G2 (BiCMOS open source)
- Volume: 10K units minimum for cost effectiveness

---

## See Also

- [`SPEC_FROZEN.md`](./SPEC_FROZEN.md) — Functional requirements
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — Block-level design rationale
- [`README.md`](./README.md) — Overview and context
- GlobalFoundries GF180MCU Process Design Kit — [github.com/google/gf180mcu-pdk](https://github.com/google/gf180mcu-pdk)
