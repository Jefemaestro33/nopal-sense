# Nopal-Sense v1 — Pin Assignment

**Pad ring:** Official Chipathon 2026 workshop 88-pin slot, based on Mauricio Montanares' fork of `wafer-space/gf180mcu-project-template`, slot `workshop`
**Die:** 2935 × 2935 µm
**Core (active design area):** 2051 × 2051 µm (~4.2 mm²)

This document specifies how Nopal-Sense lands on the Chipathon workshop pad ring and the functional assignment of its 88 pads to the chip's signals.

---

## 1. Pad Ring Overview

The Chipathon pad ring is **fixed and shared** by Track B participants using `SLOT=workshop`. The pad-ring `chip_top.sv` wires pads into a `chip_core.sv` module with an immutable port list. The Nopal-Sense design lives inside `chip_core.sv`.

### 1.1 Pad composition (per `src/slot_defines.svh` block `SLOT_WORKSHOP`)

| Cell | Count | Function |
|---|---|---|
| `clk_pad` (`gf180mcu_fd_io__in_s`) | 1 | Schmitt-trigger CMOS clock input (dedicated) |
| `rst_n_pad` (`gf180mcu_fd_io__in_c`) | 1 | Active-low reset input (dedicated) |
| Input pads (`gf180mcu_fd_io__in_c`) | 1 | Spare CMOS input. Yosys zero-width-vector workaround; usable for 1 generic input |
| Bidir pads (`gf180mcu_fd_io__bi_24t`) | 20 | 5V WR digital bidir, 24 mA drive, fast/slow slew, pull-up/down, CMOS/Schmitt select |
| Analog pads (`gf180mcu_fd_io__asig_5p0`) | 60 | 5V WR analog signal pads, double diode ESD, 10 mA DC capability |
| DVDD pads (`gf180mcu_ws_io__dvdd`) | 4 | Power supply, 60 mA DC each |
| DVSS pads (`gf180mcu_ws_io__dvss`) | 4 | Ground, 60 mA DC each |
| Corner cells (`gf180mcu_fd_io__cor`) | 4 | Inserted automatically by LibreLane |
| **Total** | **88** + 4 corners | |

### 1.2 Mechanical / physical

- Die size: 2935 × 2935 µm (includes sealring)
- Core area: 2051 × 2051 µm (`CORE_AREA: [442, 442, 2493, 2493]` in `slot_workshop.yaml`)
- Pad pitch: 75 µm per pad cell (`asig_5p0` / `bi_24t` / `dvdd` / `dvss` / `in_s` / `in_c`)
- Corner cells: 355 µm each
- Per-side pad arithmetic: 25 pads × 75 µm + 2 corners × 355 µm = 2585 µm pads + 710 µm corners — die side 2935 µm gives ~350 µm filler slack per side (healthy margin)

### 1.3 Pad ordering convention

LibreLane reads `PAD_*` lists clockwise starting from the south-west corner:

```
         PAD_NORTH (entries read E -> W in YAML)
         * -------------------- *
         |                      |
  PAD_   |                      |   PAD_
  WEST   |      chip_core       |   EAST
  (N->S) |                      |  (S->N)
         |                      |
         * -------------------- *
         PAD_SOUTH (entries read W -> E in YAML)
```

---

## 2. `chip_core.sv` port contract (workshop slot)

Immutable. The RTL must match this signature exactly:

```verilog
module chip_core #(
    parameter NUM_INPUT_PADS,    // = 1 for workshop slot
    parameter NUM_BIDIR_PADS,    // = 20
    parameter NUM_ANALOG_PADS    // = 60
)(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input  wire clk,                                  // from dedicated clk_pad
    input  wire rst_n,                                // from dedicated rst_n_pad (active-low)
    input  wire [NUM_INPUT_PADS-1:0]  input_in,       // 1 spare CMOS input
    output wire [NUM_INPUT_PADS-1:0]  input_pu,       // tie to '0
    output wire [NUM_INPUT_PADS-1:0]  input_pd,       // tie to '0
    input  wire [NUM_BIDIR_PADS-1:0]  bidir_in,       // 20 bidir inputs
    output wire [NUM_BIDIR_PADS-1:0]  bidir_out,      // 20 bidir outputs
    output wire [NUM_BIDIR_PADS-1:0]  bidir_oe,       // output enable per pad
    output wire [NUM_BIDIR_PADS-1:0]  bidir_cs,       // CMOS (0) / Schmitt (1) input
    output wire [NUM_BIDIR_PADS-1:0]  bidir_sl,       // fast (0) / slow (1) slew
    output wire [NUM_BIDIR_PADS-1:0]  bidir_ie,       // input enable (tie ~oe)
    output wire [NUM_BIDIR_PADS-1:0]  bidir_pu,       // pull-up enable per pad
    output wire [NUM_BIDIR_PADS-1:0]  bidir_pd,       // pull-down enable per pad
    inout  wire [NUM_ANALOG_PADS-1:0] analog          // 60 analog pads (5V WR)
);
```

### 2.1 Default-safe bidir pad controls

Use this default in `chip_core.sv` unless there is a specific reason to diverge:

```verilog
assign input_pu = '0;
assign input_pd = '0;
assign bidir_cs = '0;    // CMOS buffer (not Schmitt) — default for most signals
assign bidir_sl = '0;    // fast slew — default for SPI/digital comms
assign bidir_pu = '0;    // no pull-up
assign bidir_pd = '0;    // no pull-down
assign bidir_ie = ~bidir_oe;  // input enable opposite to output enable
// Drive bidir_oe per signal: 1 for chip-driven outputs, 0 for chip-sampled inputs.
```

---

## 3. Functional assignment for Nopal-Sense

Logical-to-pad assignment for the workshop slot's 20 bidirectional and 60 analog pads. Physical clockwise pad ordering belongs in `slot_workshop.yaml`; this document only records the logical assignment.

### 3.1 Digital bidir (20 pads available)

| bidir[N] | Signal | Direction | Function |
|---|---|---|---|
| 0 | `MOSI_S` | input | SPI slave data in (from ESP32) |
| 1 | `MISO_S` | output | SPI slave data out (to ESP32) |
| 2 | `SCK_S` | input | SPI slave clock |
| 3 | `CS_S` | input, active-low | SPI slave chip select |
| 4 | `INT_OUT` | output, active-low | Interrupt aggregator (wakes ESP32) |
| 5 | `CS_MEM` | output, active-low | External FeRAM chip select |
| 6-12 | `GPIO_SW[0..6]` | output | 7 programmable power switches (24 mA bidir drive) |
| 13 | `OWIRE` | bidir, open-drain | 1-Wire master (DS18B20 + DS28E07 probe IDs) |
| 14 | `I2C_SDA` | bidir, open-drain | Bit-banged I2C data (ATECC608 + other I2C sensors) |
| 15 | `I2C_SCL` | output, open-drain | Bit-banged I2C clock |
| 16 | `MOSI_M` | output | SPI master out (FeRAM external) |
| 17 | `MISO_M` | input | SPI master in |
| 18 | `SCK_M` | output | SPI master clock |
| 19 | `PULSE_IN` / `TAMPER` muxed | input | EC probe pulse counter OR tamper reed switch (mode bit selects) |

**Explicit trade-offs vs the original QFN-40-oriented SPEC:**
- `EN_LDO` removed: v1 uses a single 3.3 V architecture with no external LDO enable pin.
- `CLK_OUT` removed from the external pinout to dedicate `bidir[5]` to `CS_MEM`; SPI memory requires chip select and SCK simultaneously.
- `PULSE_IN[1]` (rain/wind) deferred to v2; v1 keeps one pulse input.
- `TAMPER` muxed with `PULSE_IN[0]`; tamper is static and does not contend with the pulse counter in the intended modes.

### 3.2 Analog (60 pads available)

Active assignment: 12 of 60 pads used. The remaining 48 pads are reserved for v1.1, debug, or test points.

| analog[N] | Signal | Direction | Function |
|---|---|---|---|
| 0 | `ELEC_A` | bidir, drive | IS electrode A (excitation output, 10 mA cap) |
| 1 | `ELEC_B` | bidir, sense | IS electrode B (sense input to TIA) |
| 2 | `VREF_OUT` | output | Bandgap 1.2V exported (±0.05% target) |
| 3-10 | `ADC_IN[0..7]` | input | 8-channel external analog input MUX to internal ADC |
| 11 | `TEST_VBG` | bidir | Test point for internal bandgap (bring-up) |
| 12-59 | unassigned | — | Reserved for v1.1 / oscilloscope debug taps |

### 3.3 Dedicated pads (not in bidir/analog count)

| Pad | Signal | Function |
|---|---|---|
| `clk_pad` | `clk` | External 1 MHz clock input (Schmitt). Can also use internal RC if `clk` floats |
| `rst_n_pad` | `rst_n` | External active-low reset |
| `input[0]` | spare | Used for `SPI_DEBUG_EN` or tie to GND if unused |
| DVDD × 4 | VDD | 3.3V supply (4 pads distributed around the pad ring for IR drop) |
| DVSS × 4 | GND | Ground (4 pads distributed) |

---

## 4. Electrical specifications

### 4.1 Absolute maximum ratings

| Parameter | Min | Max | Unit | Notes |
|---|---|---|---|---|
| VDD | -0.3 | 3.6 | V | Single rail; gf180mcuD does not ship native 1.8 V standard cells |
| Voltage on any digital I/O | -0.3 | 5.5 | V | I/O cells are 5 V wide-range pads; tolerant of external 5 V signals |
| Voltage on analog input | -0.3 | VDD + 0.3 | V | `asig_5p0` with double-diode protection |
| Storage temperature | -40 | 85 | °C | |
| Junction temperature | — | 125 | °C | |
| ESD (HBM) | 2000 | — | V | Per `asig_5p0` and `bi_24t` cell specs |
| ESD (CDM) | 500 | — | V | |
| Latch-up current | 100 | — | mA | JESD78 Class II Level A |

### 4.2 Recommended operating conditions

| Parameter | Min | Typ | Max | Unit |
|---|---|---|---|---|
| VDD | 3.00 | 3.30 | 3.60 | V |
| Operating temperature | -10 | 25 | 70 | °C |
| Input low (VIL) digital | — | — | 0.3 × VDD | V |
| Input high (VIH) digital | 0.7 × VDD | — | — | V |

### 4.3 Current per mode

| Mode | Typical | Max |
|---|---|---|
| DEEP_SLEEP | 0.5 µA | 3 µA |
| NORMAL (active 300 ms) | 1.5 mA | 3 mA |
| ALERT | 0.5 mA avg | 1 mA |
| VALIDATION | 5 mA | 8 mA |
| DEBUG | 8 mA | 12 mA |

### 4.4 I/O timing

| Parameter | Min | Max | Notes |
|---|---|---|---|
| SPI slave clock | — | 250 kHz | Synchronous slave sampled by 1 MHz system clock |
| Setup time (MOSI to SCK) | 5 ns | — | |
| Hold time (MOSI after SCK) | 5 ns | — | |
| Clock-to-out (SCK to MISO) | — | 15 ns | |
| 1-Wire timing | Per Maxim DS18B20 spec | | |
| I2C timing | Per I2C standard 100 kHz | | |

---

## 5. PCB layout guidelines

The pad ring of the Chipathon shuttle is packaged by Channel Partner; the participant does not specify the package directly. For evaluation PCB design (Phase 5 bring-up Q1 2027):

### 5.1 Ground plane strategy

- **GL-001:** Single-point GND star topology — analog GND and digital GND join at one point on the PCB near the chip
- **GL-002:** Separate GND plane zones for digital (ESP32, LoRa) and analog (probes, sensors) sides
- **GL-003:** All DVSS pads tied to PCB GND with multiple vias
- **GL-004:** Do not route signals under the chip footprint (use opposite layer)

### 5.2 Power decoupling

- **GL-005:** 100 nF + 10 µF per DVDD pad, within 5 mm
- **GL-006:** Use X7R or C0G dielectric for accuracy (not Y5V)
- **GL-007:** Bulk capacitance shared across DVDD pads, individual 100 nF per pad

### 5.3 Analog signal routing

- **GL-008:** `ELEC_A`, `ELEC_B` traces: minimize length; guard traces tied to analog GND
- **GL-009:** ADC inputs: low-ESR RC filter (100 Ω + 100 nF) close to chip pad
- **GL-010:** Avoid crossing digital signals under analog traces
- **GL-011:** Keep IS electrode cable <2 m to minimize parasitic capacitance

### 5.4 Memory SPI routing

- **GL-012:** Route `SCK_M` and `CS_MEM` as a short, matched pair to the external FeRAM device.
- **GL-013:** Keep SPI memory traces away from sensitive analog routes and add series damping if edge ringing appears during bring-up.

### 5.5 Reset and power-up

- **GL-014:** `rst_n` external pull-up 10 kΩ + 100 nF to GND (time constant ~1 ms)
- **GL-015:** Power sequencing: VDD monotonic ramp, no inrush spikes during POR

### 5.6 ESD protection (external)

For cables going outside the enclosure (sensor probes, electrodes):

- **GL-016:** Add TVS diodes (e.g., SRV05-4) at cable entry
- **GL-017:** Ferrite beads on power lines to external sensors
- **GL-018:** Internal `asig_5p0` ESD handles 2 kV HBM; external TVS covers field transients

---

## 6. Bring-up reference (Phase 5, Q1 2027)

After chip arrival from Channel Partner:

1. **Power-on test** — verify DVDD pads at 3.3V, sleep current <3 µA
2. **VERSION register read** via SPI slave (`bidir[0..3]`) — expect 0x0100
3. **Bandgap export check** — `VREF_OUT` on `analog[2]` should be 1.2V ±0.05%
4. **External FeRAM chip-select** on `bidir[5]` should idle high and assert low during SPI memory transactions
5. **ADC sanity** via `ADC_IN[0]` on `analog[3]` with known voltage reference
6. **IS measurement loop** — drive `ELEC_A` (`analog[0]`), sense `ELEC_B` (`analog[1]`) against known impedances

---

## See also

- `SPEC_FROZEN.md` — Functional requirements + register map
- `ARCHITECTURE.md` — Block-level design rationale
- `README.md` — Overview
- Workshop slot upstream: [`resources/Integration/workshop_padring_librelane/`](https://github.com/sscs-ose/sscs-chipathon-2026/tree/main/resources/Integration/workshop_padring_librelane) in the chipathon repo
- Slot anatomy walkthrough: [`examples/librelane_rtl2gds_gf180/00_slots_explained.ipynb`](https://github.com/sscs-ose/sscs-chipathon-2026/blob/main/examples/librelane_rtl2gds_gf180/00_slots_explained.ipynb)
- Pad cells reference: [GF180MCU PDK IO library](https://gf180mcu-pdk.readthedocs.io/en/latest/IPs/IO/gf180mcu_fd_io/datasheet.html)
