# PICO Chipathon 2026 — Application Draft

> ## ⚠️ Historical Document — Original Submission
>
> This is the original application draft submitted to IEEE PICO Chipathon 2026
> on **April 10, 2026**. The chip design has since evolved based on deeper
> analysis of the value proposition (see [Design Evolution](#design-evolution) below).
>
> **For current design, see:**
> - [`README.md`](./README.md) — Overview of v1 (PICO 2026)
> - [`SPEC_FROZEN.md`](./SPEC_FROZEN.md) — Frozen specification
> - [`ARCHITECTURE.md`](./ARCHITECTURE.md) — Block-level rationale
> - [`PIN_ASSIGNMENT.md`](./PIN_ASSIGNMENT.md) — Physical pinout
>
> The Track B (Circuits for Sensors) and Track D (AI/LLM-assisted) selections
> from this application **remain valid** in the current design. The scope
> expansion to mixed-signal with impedance spectroscopy is additive, not
> a pivot away from sensor processing.
>
> This document is preserved as the official record of what was submitted
> to IEEE. The mentor will be briefed on the current scope at onboarding
> (see [`MENTOR_BRIEFING.md`](./MENTOR_BRIEFING.md)).

**Sign-up form:** https://docs.google.com/forms/d/e/1FAIpQLSdu3lsgLVK43BlM5mAgISv5cjN7PuF5CqA8LfEz4fX3Xzl8eQ/viewform

**Deadline:** May 1, 2026

**Status:** Submitted 2026-04-10

---

## Design Evolution

After submitting this application, the design evolved significantly:

| Aspect | Original (this doc) | Current (SPEC_FROZEN.md) |
|--------|---------------------|---------------------------|
| **Architecture** | Digital-only, 14 modules | Mixed-signal (digital + analog) |
| **Flagship capability** | Phytophthora scoring on silicon | **Impedance Spectroscopy** |
| **Phytophthora scoring** | Implemented on-chip (4 factors) | Moved to VPS (allows iteration) |
| **Sensor consolidation** | Read existing sensors | **Replaces 5 sensors with 1 chip + pins** |
| **Direct pathogen detection** | No (environmental proxy only) | **Yes — via biofilm impedance signature** |
| **Connectivity bridges** | N/A | **12 specific bridges for deferred features** |
| **Architectural exports** | N/A | **4 "gifts" to external components** |

**Why the evolution:** Further analysis revealed that implementing environmental
scoring in silicon (a) duplicated functionality easily done in ESP32 firmware,
and (b) locked the chip to a specific version of the scoring model that needs
to iterate with lab-validated data. Impedance spectroscopy provides a genuinely
silicon-only capability that no off-the-shelf MCU can replicate at <$10 USD
per node, and complements (rather than replaces) the environmental scoring
that remains in the cloud.

---

## Project Title

**Nopal-Sense: Open-Source Agricultural Sensor Co-Processor for Phytophthora Detection in Avocado Orchards**

## Preferred Track(s)

- **Track B: Circuits for Sensors** (primary)
- **Track D: AI/LLM-assisted Circuits** (secondary — entire RTL designed with Claude AI)

## Background

I am a bioinformatician and AgTech developer from Guadalajara, Mexico. I have built
a complete precision agriculture platform (Zafra-AgTech) for avocado orchards: 
firmware for ESP32+LoRa sensor nodes (soil moisture at 3 depths, temperature, EC),
a Python backend with 44+ API endpoints, Phytophthora risk scoring (v3, 10-factor
model), hydrologic balance with FAO-56 irrigation prescriptions, and WhatsApp
alerting. The system is designed for Andisol volcanic soils in Nextipac, Jalisco
and is ready for field deployment.

The key barrier to deployment is node cost and battery life. Current nodes using
ESP32 are expensive ($35+/node) and last only 2-3 weeks on battery due to the MCU
running sensor processing firmware. Moving critical processing to a dedicated chip
would reduce active time from 5 minutes to 5 seconds per cycle, extending battery
life 5-10× and making large-scale deployment economically viable.

I have recently completed my first chip design experience through the Tiny Tapeout
program (cellular automaton on VGA, passed synthesis and TT precheck on SKY130),
using open-source tools (Yosys, OpenLane, cocotb) and Claude AI as design co-pilot.

## Project Description

Nopal-Sense is a dedicated hardware co-processor that moves critical agricultural
sensor processing from cloud software to silicon:

1. **Sensor interfaces:** SPI master (capacitive humidity via ADS1115), I2C master
   (DS18B20 temperature), frequency counter (EC probe)
2. **Calibration engine:** Configurable polynomial (a*x^2 + b*x + c) with temperature
   correction, loaded per-deployment via SPI registers
3. **Signal conditioning:** Moving average filter (window 4/8/16)
4. **Agronomic calculations:** VPD (Vapor Pressure Deficit) via LUT-based Tetens
   equation, simplified Hargreaves ET0
5. **Phytophthora risk detector:** Hardware implementation of 4-factor scoring model
   (soil saturation, optimal temperature range, continuous wet hours, dual-depth
   saturation) with configurable thresholds
6. **SRAM PUF:** Hardware identity for chip authentication and encrypted calibration
7. **CRC16 engine:** Data integrity for LoRa transmission (currently missing from system)
8. **Ultra-low-power:** Clock-gated sleep mode with autonomous wake timer

The chip connects as SPI slave to an ESP32+LoRa module, replacing 346 lines of
firmware with ~50 lines, reducing MCU active time from 5 minutes to 5 seconds per
cycle, and extending battery life 5-10x.

## Why GF180MCU

The GF180MCU high-voltage capability (up to 10.5V I/O) is ideal for direct interfacing
with agricultural sensors that operate at 3.3V-5V, eliminating the need for level
shifters. The 180nm node is well-suited for low-power sensor processing where
clock speed is not critical (target: 1-10 MHz).

## Validation Plan

1. **Golden model validation:** Full Python model of the processing pipeline
   (already built and running) generates realistic sensor scenarios based on
   Andisol soil parameters from FAO literature and Phytophthora cinnamomi 
   epidemiological models.
2. **Bit-exact verification:** Each Verilog module validated against the Python
   golden model using cocotb testbenches with 1000+ test vectors per module.
3. **Scenario testing:** 24-hour simulated farming days including irrigation
   events, temperature cycles, pathogen risk windows, and edge cases.
4. **Post-silicon field deployment:** Connect fabricated chip to real soil sensors
   (capacitive moisture, DS18B20, EC probe) in an avocado orchard in Jalisco.
   This will be the first real-world validation and generate actual field data
   for calibration refinement.

## AI/LLM-Assisted Design (Track D)

The entire RTL is co-designed with Claude (Anthropic). Each module is:
1. Specified in natural language
2. Generated by Claude in Verilog
3. Reviewed and iterated through conversation
4. Verified with Claude-generated cocotb testbenches
5. Documented with Claude-generated datasheets

This demonstrates that a single designer + AI can produce silicon-ready designs
that previously required a team of 5-10 engineers.

## Team

- **Darell Plascencia** — Bioinformatician, AgTech developer, chip designer
  - Location: Guadalajara, Mexico
  - Background: Bioinformatics, data science, precision agriculture
  - GitHub: Jefemaestro33
  - Current project: Zafra-AgTech (operational sensor network)
  - First chip: tt-nopal-demo (TT Demoscene, SKY130, passed precheck)

## Availability

Available for weekly meetings and periodic design reviews throughout the program
(May-September 2026). Full-time dedication to design during June-August.

## Why This Matters

Mexico is the world's #1 avocado exporter. Phytophthora cinnamomi causes $100M+
in annual losses to Mexican avocado production. An ultra-low-cost, ultra-low-power
sensor co-processor that detects Phytophthora risk conditions autonomously — without
depending on internet connectivity — could protect thousands of hectares.

This would be the first semiconductor IP designed in Mexico specifically for
agricultural applications.
