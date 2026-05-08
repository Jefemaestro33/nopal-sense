# Mentor Briefing — Nopal-Sense v1

**For:** PICO Chipathon 2026 mentor assignment (2026-05-01)
**From:** Darell Plascencia — [Jefemaestro33](https://github.com/Jefemaestro33)
**Reading time:** ~3 minutes

---

## TL;DR

I'm designing a **mixed-signal sensor hub ASIC for agricultural IoT nodes** with impedance spectroscopy as the flagship capability. Target: direct detection of soil biofilms (Phytophthora cinnamomi) at <$10 USD per node.

Previous chip experience: Tiny Tapeout digital chip (SKY130, passed precheck).
This is my first mixed-signal design.

**I need a mentor with analog/mixed-signal background.** Digital-only mentorship is insufficient for this design.

---

## The Chip at a Glance

- **Process:** GF180MCU 180nm (IEEE-provided)
- **Package:** QFN-40, ~2.7 mm²
- **Flagship:** Impedance spectroscopy at 3 fixed frequencies (1 kHz, 100 kHz, 1 MHz)
- **Consolidates:** 5 traditional sensors (EC probe + 3 capacitive moisture + signal conditioning) into 1 chip + passive probes
- **Target power:** <1 µA sleep, <2 mA active
- **Interface:** SPI slave to ESP32 host

Full specification: [`SPEC_FROZEN.md`](./SPEC_FROZEN.md)
Architecture rationale: [`ARCHITECTURE.md`](./ARCHITECTURE.md)
Pin assignment: [`PIN_ASSIGNMENT.md`](./PIN_ASSIGNMENT.md)

---

## Status (2026-04-18)

### ✅ Complete
- System architecture + 3-layer design (silicon / firmware / VPS)
- Frozen specification with 75+ numbered requirements
- Register map (32 × 16-bit)
- Pin assignment (QFN-40)
- Block-level area estimates (total 2.64 mm², 30% margin)
- Power budget per block + per cycle
- Python golden model (partial — see `sim/golden_model.py`)
- Business context + go-to-market plan (Zafra-AgTech piloto 2026)
- Prior benchtop work: 416K+ soil sensor readings from field deployment

### ⏳ In progress
- Completing Python golden model (all blocks + Randles soil physics)
- Test vector generation for cocotb

### ❌ Pending (need mentor help)
- Analog block design: TIA, mixer I/Q, DAC, bandgap reference
- Mixed-signal verification flow
- Layout strategy (analog/digital separation, guard rings)
- Process corner analysis strategy

---

## Track Selection

- **Primary:** Track B — Circuits for Sensors
- **Secondary:** Track D — AI/LLM-assisted Circuits (entire RTL co-designed with Claude)

---

## Specific Questions for Mentor

### Analog design
1. For the TIA with auto-ranging in 180nm, what topology do you recommend? (Shunt-feedback op-amp with FET-switched resistor ladder seems reasonable, but I have no prior experience.)
2. Is 14-bit SAR ADC realistic in 180nm at 20 kSPS? What's the typical area budget and gotchas?
3. For IS mixer: analog multiplier vs switching demodulator — which has better noise performance for our dynamic range?
4. What's the minimum bandgap reference quality needed for 3% IS accuracy? PTAT-compensated CTAT?

### Verification
5. What's your recommended cocotb + Spectre AMS flow? Any preferred setup?
6. How many Monte Carlo runs are needed for sign-off in 180nm mixed-signal?
7. Process corners to prioritize: TT, FF, SS, FS, SF — which are most critical for this design?

### Risk
8. What's your gut check on timeline? Is this scope achievable for a first-time mixed-signal designer in 4 months with weekly mentorship?
9. What's the single feature most likely to fail tape-out as I've scoped it?
10. Should I scope down further before mentor assignment (drop to 2 IS frequencies, drop auto-range)?

### Process specifics
11. GF180MCU analog cells — are there good reference designs I should study first?
12. Does GF180MCU PDK include reasonable verification IP, or should I budget time to build my own?

---

## What I Bring

- **Domain expertise:** Bioinformatics + AgTech (operational precision agriculture system in Jalisco)
- **Real sensor data:** 416K+ readings from field deployment (for algorithm validation)
- **Software discipline:** Full backend, dashboard, Phytophthora scoring v3 in production
- **Writing/communication:** Extensive documentation already drafted
- **Time:** Full-time dedication June-August 2026; part-time May + Sept
- **Prior silicon experience:** Tiny Tapeout digital chip, GDS generated, precheck passed

---

## What I Need from Mentor

1. **Weekly 1-on-1 calls** (1 hour, preferably video + screen share)
2. **Review of analog block designs** before layout
3. **Mixed-signal verification guidance** (Spectre AMS or equivalent)
4. **Reality check on scope** — willing to cut features to ship on time
5. **Review of tape-out submission package**

I can work asynchronously outside weekly calls. I'm disciplined about preparing specific questions before each meeting.

---

## Logistics

- **Time zone:** Guadalajara, Mexico (UTC-6)
- **Availability:** Flexible, can match mentor's schedule
- **Preferred cadence:** Weekly 1h call + async messaging (Matrix / Discord / Slack / email)
- **Language:** English or Spanish
- **Contact:** via Matrix chipathon channel or GitHub [@Jefemaestro33](https://github.com/Jefemaestro33)

---

## Backup Plans (if mentor matching isn't ideal)

If assigned mentor is digital-only, I can:
- Scope down to simpler sensor hub (drop IS to v2)
- Partner with another team's mentor for analog reviews
- Use pdk forums + community for analog questions

But **prefer to preserve IS as flagship** — it's what makes this project uniquely valuable.

---

**One-line ask:** *Please assign a mentor who has taped out mixed-signal designs with on-chip ADCs and analog front-ends, ideally with biosensing or instrumentation background.*
