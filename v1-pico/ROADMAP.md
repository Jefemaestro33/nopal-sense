# Nopal-Sense v1 — Execution Roadmap

**Period covered:** 2026-05-08 (Chipathon kickoff) → 2027-07-31 (IEEE workshop + paper submission)
**Document type:** Executable project roadmap with gates, deliverables, decision log, and risk register
**Owner:** Ernest Darell Zermeño Plascencia
**Status:** Active — updated as execution progresses
**Last major update:** 2026-05-08 — strategic clarifications (vertical integration, 3-stage research, dual-pilot)

This document is the **operational manual** for executing Nopal-Sense v1 from spec to **greenhouse-validated science** (Q2 2027) and paper submission (July 2027). It consolidates phase-by-phase deliverables, gates of decision, the history of decisions already taken, and active risks with mitigation owners.

> ⚠️ **2026-05-08 Note**: Algunas fechas y referencias (especialmente PICO onboarding "1 may", QFN-40, 1.8V dual voltage) reflejan asunciones del SPEC original. Realidad post-validation:
> - **Kickoff fue 8 may 2026** (Boris Murmann + Mehdi Saligane), no 1 may
> - **Padring**: workshop slot 88-pin, no QFN-40
> - **Voltaje**: 3.3V único, no dual 1.8V/3.3V
> - **Tape-out**: ~oct 2026 (post Final Chip Review 28 sept), no 30 sept
> - **Phase 7**: greenhouse pilot (validar science con chips chipathon), NO field deployment directo. Field continúa con commercial sensor stack hasta v2 chip ready (2029-2030).
>
> Para framing estratégico actual, ver [`../README.md`](../README.md), [`../docs/research_program.md`](../docs/research_program.md), [`../docs/business_model.md`](../docs/business_model.md), y [`../CHANGELOG.md`](../CHANGELOG.md) (entry 2026-05-08).

---

## 1. Overall timeline (8 phases, 15 months)

```
2026                                                                   2027
│                                                                      │
├─ MAY ──── Phase 1: Onboarding + RTL Core                             │
│          Gate 1: 3 digital modules passing tests                     │
│                                                                      │
├─ JUN ──┐                                                             │
│        ├─ Phase 2: Analog Design                                     │
├─ JUL ──┘  Gate 2: Analog schematics approved by mentor               │
│                                                                      │
├─ JUL ──┐                                                             │
│        ├─ Phase 3: Integration + Verification                        │
├─ AUG ──┘  Gate 3: Full-chip verification passing all corners         │
│                                                                      │
├─ AUG ──┐                                                             │
│        ├─ Phase 4: Layout + Tape-out                                 │
├─ SEP ──┘  Gate 4: Tape-out submitted to GF180MCU shuttle             │
│                                                                      │
├─ OCT ──┐                                                             │
├─ NOV ──┤                                                             │
├─ DEC ──┤   Phase 5: Fab wait + Bring-up preparation                  │
├─ JAN ──┘  Gate 5: Bring-up infrastructure ready (PCB, firmware, lab) │
│                                                                      │
│         ──┐                                                          │
│           │ Phase 6: Chip arrival + Bring-up                         │
│         ──┘  Gate 6: Silicon operational (SPI + IS functional)       │
│                                                                      │
│               ├─ FEB                                                 │
│               │                                                      │
│               ├─ MAR ──┐                                             │
│               │         ├─ Phase 7: Field Validation                 │
│               ├─ APR ──┤                                             │
│               │         │                                            │
│               ├─ MAY ──┤                                             │
│               │         │                                            │
│               ├─ JUN ──┘  Gate 7: Publication-ready dataset          │
│               │                                                      │
│               ├─ JUL ── Phase 8: Paper + IEEE Workshop               │
│               │          Gate 8: Paper submitted + workshop presented
└───────────────┘                                                      │
```

---

## 2. Phase-by-phase execution

### Phase 1 — Onboarding + RTL Core (2026-05-01 to 2026-05-31)

**Purpose:** Lock in scope with mentor, produce first verified digital RTL modules.

#### Week 1 (May 1-7): Onboarding + Alignment
- [ ] Attend PICO Chipathon onboarding session (May 1)
- [ ] Confirm mentor assignment; request mixed-signal background if possible
- [ ] Share SPEC_FROZEN.md + ARCHITECTURE.md + MENTOR_BRIEFING.md with mentor
- [ ] First 1-on-1 with mentor: walk through Open Questions in ARCHITECTURE.md §10
- [ ] Resolve OQ-001 (second ADC?), OQ-002 (64-bit PUF?), OQ-003 (BOD?), OQ-004 (scheduler flexibility), OQ-005 (test pins)
- [ ] Update SPEC_FROZEN.md with mentor-approved amendments (if any) → version 0.2

#### Week 2 (May 8-14): RTL Core Digital Modules
- [ ] Update `rtl/spi_slave.v` to `DATA_W = 16` (currently 8-bit from reuse)
- [ ] Write `rtl/reg_bank.v` new (32 × 16-bit with readonly mask per SPEC §5)
- [ ] Start `rtl/onewire_master.v` (DS18B20 timing + DS28E07 ID read)
- [ ] Set up cocotb + Icarus Verilog test environment
- [ ] Generate test vectors from golden model: `python3 sim/golden_model.py --gen-vectors`

#### Week 3 (May 15-21): RTL Verification
- [ ] Complete `onewire_master.v` + testbench
- [ ] Write testbench for `spi_slave.v` (bit-exact vs golden model)
- [ ] Write testbench for `reg_bank.v` (readonly mask, defaults, SPI access)
- [ ] Start `rtl/pulse_counter.v` + `rtl/crc16.v`
- [ ] Weekly mentor review

#### Week 4 (May 22-31): Stabilization + Handoff Prep for Phase 2
- [ ] Complete `pulse_counter.v` + `crc16.v` + tests
- [ ] Coverage report: line ≥ 95%, branch ≥ 90% for completed modules
- [ ] Documentation: update `v1-pico/README.md` with actual RTL status
- [ ] Mentor review: are we on schedule for analog kickoff June 1?

#### 🚪 Gate 1 Criteria (must pass by 2026-05-31)
- ✅ 5 digital modules functional and tested: `spi_slave`, `reg_bank`, `onewire_master`, `pulse_counter`, `crc16`
- ✅ All modules bit-exact vs golden model (1000+ random vectors each)
- ✅ Mentor sign-off on digital foundation
- ✅ Spec version 0.2 published (with any amendments)

**If Gate 1 fails:** Analyze which module blocked; reduce scope if necessary (e.g., ship without CRC if needed, add back in v2).

---

### Phase 2 — Analog Design (2026-06-01 to 2026-07-15)

**Purpose:** Design and simulate the analog blocks that make IS possible.

#### Week 5-6 (Jun 1-14): Bandgap + Reference
- [ ] Design bandgap reference in Cadence Virtuoso (or equivalent PDK tool)
- [ ] Simulate across corners (TT, FF, SS, FS, SF)
- [ ] Target: ±0.05% accuracy at 25°C, ±0.2% across temp range
- [ ] Mentor review of topology before committing

#### Week 7-8 (Jun 15-28): TIA (Transimpedance Amplifier)
- [ ] Design TIA with programmable gain (6 levels: 1x, 10x, 100x, 1k, 10k, 100k)
- [ ] Auto-range state machine (digital side) coordinated with analog
- [ ] Noise analysis; target: input-referred noise < 1 µV/√Hz
- [ ] Monte Carlo 100 runs

#### Week 9-10 (Jun 29 - Jul 12): DAC + DDS + Mixer
- [ ] DAC 10-bit design (target THD < -60 dB)
- [ ] DDS digital block (phase accumulator, sine LUT 256 entries quarter-wave)
- [ ] Mixer I/Q (switching multiplier approach)
- [ ] Integration simulation of DDS → DAC → buffer → external load

#### Week 11 (Jul 13-15): ADC 14-bit SAR
- [ ] ADC design or IP integration
- [ ] INL/DNL verification < 2 LSB / 1 LSB target
- [ ] Conversion timing verified (< 50 µs/sample)

#### 🚪 Gate 2 Criteria (must pass by 2026-07-15)
- ✅ All analog blocks simulated in SPICE (Spectre)
- ✅ Process corners clean (TT, FF, SS, FS, SF)
- ✅ Temperature sweep -10°C to 70°C all specs met
- ✅ Monte Carlo 100 runs: no spec violations in ±3σ
- ✅ Mentor sign-off on analog schematics

**If Gate 2 fails:** Likely TIA (first-time analog for designer). Mitigation: drop auto-range complexity to 3 gain levels instead of 6, or use a simpler shunt-feedback op-amp topology.

---

### Phase 3 — Integration + Verification (2026-07-15 to 2026-08-15)

**Purpose:** Integrate analog + digital and verify the full chip meets all REQs.

#### Week 12 (Jul 15-21): Top-level integration
- [ ] Write `rtl/nopal_sense_top.v` integrating all modules
- [ ] Add scheduler FSM (`rtl/scheduler.v`)
- [ ] Connect analog interface signals (DAC control, ADC data, TIA gain select)

#### Week 13 (Jul 22-28): Mixed-signal co-simulation
- [ ] Set up Spectre AMS Designer environment
- [ ] Run full IS measurement cycle in simulation
- [ ] Compare against golden model output → must match within spec accuracy

#### Week 14 (Jul 29 - Aug 4): Corner analysis
- [ ] Process corners × temperature × supply voltage (27 combinations)
- [ ] Identify worst-case corner for each spec parameter
- [ ] Monte Carlo 1000 runs on critical paths

#### Week 15 (Aug 5-15): Power analysis + timing closure
- [ ] Power-aware simulation confirms <1 µA sleep, <2 mA active
- [ ] Timing closure at 1 MHz + 10% margin
- [ ] Remaining digital modules: sleep_ctrl, puf, alert_engine, moving_avg

#### 🚪 Gate 3 Criteria (must pass by 2026-08-15)
- ✅ Full-chip simulation passes for all 5 operating modes
- ✅ All REQ-* verifiable REQs have passing tests
- ✅ Power budget validated: <1 µA sleep typical, <2 mA active during IS
- ✅ Timing closure: no violations at nominal; < 5% margin at worst corner
- ✅ Mentor sign-off on verification coverage

**If Gate 3 fails:** Most likely in mixed-signal corners. Mitigation: narrow operating range (cut temperature sweep to -5 to 65°C instead of -10 to 70°C).

---

### Phase 4 — Layout + Tape-out (2026-08-15 to 2026-09-30)

**Purpose:** Transform verified schematics into physical chip layout ready for fabrication.

#### Week 16-17 (Aug 15-28): Floorplan + analog layout
- [ ] Define floorplan (power stripes, guard rings, die area 2.7 mm²)
- [ ] Layout bandgap, TIA, mixer, ADC, DAC (analog is hardest)
- [ ] Matching considerations (common-centroid for current mirrors)

#### Week 18-19 (Aug 29 - Sep 11): Digital layout + integration
- [ ] OpenLane synthesis for digital blocks
- [ ] Place-and-route with constraints
- [ ] Integrate analog + digital in top-level floorplan
- [ ] Power distribution network

#### Week 20 (Sep 12-18): DRC + LVS + Antenna
- [ ] DRC clean: 0 violations across all rules
- [ ] LVS: schematic matches layout, 100% net-by-net match
- [ ] Antenna checks: no violations
- [ ] Fix iteratively until clean

#### Week 21 (Sep 19-30): Tape-out submission
- [ ] Timing closure verified at final layout
- [ ] Final GDS generated
- [ ] PICO submission package: GDS + documentation + bondmap + test plan
- [ ] Submit to GlobalFoundries shuttle via PICO Chipathon
- [ ] **TAPE-OUT: ≤ 2026-09-30**

#### 🚪 Gate 4 Criteria (must pass by 2026-09-30)
- ✅ DRC clean
- ✅ LVS clean
- ✅ Antenna clean
- ✅ Timing clean (nominal + corners)
- ✅ Tape-out package submitted
- ✅ Mentor sign-off on submission

**If Gate 4 fails:** Missing the shuttle means 3-6 month delay. Mitigation: submit what's clean, even if scope is reduced. A working chip with fewer features > no chip.

---

### Phase 5 — Fab wait + Bring-up Preparation (2026-10-01 to 2027-01-15)

**Purpose:** While chips are being fabricated (3-4 months), prepare everything needed to bring them up immediately when they arrive.

#### Month 1 (October 2026): PCB design
- [ ] Design evaluation PCB in KiCad (4-layer, mixed-signal layout)
- [ ] BOM: Nopal-Sense chip + ESP32 + sensors + IS electrodes + connectors
- [ ] Apply layout guidelines from `PIN_ASSIGNMENT.md` §5
- [ ] Send PCB gerbers to JLCPCB (or equivalent)

#### Month 2 (November 2026): PCB receive + ESP32 firmware
- [ ] Receive PCBs (~2 weeks from fab)
- [ ] Assemble dummy PCB (without Nopal-Sense chip yet) to validate
- [ ] Write ESP32 firmware for bring-up testing:
  - [ ] SPI master to talk to chip
  - [ ] Test harness to read every register
  - [ ] Debug console
  - [ ] Test vector replay
- [ ] FPGA validation: upload RTL to iCE40 or Cyclone, verify in hardware

#### Month 3 (December 2026): Measurement setup + packaging
- [ ] Research packaging options (QFN-40 wire-bonding service)
- [ ] Contact packaging vendor; prepare bondmap
- [ ] Set up lab measurement station:
  - [ ] Oscilloscope with precision probes
  - [ ] Source-meter for power measurements
  - [ ] Soil samples from Nextipac (refrigerated for baseline)
  - [ ] Electrodes ready for IS measurement
- [ ] Write bring-up checklist (runbook for when chips arrive)

#### Month 4 (January 2027): Final prep + AD5933 baseline
- [ ] Purchase AD5933 breakout + electrodes + impedance reference standards
- [ ] Measure soil samples with commercial IS equipment → baseline dataset
- [ ] Document expected Z(ω) ranges for healthy vs infected soil
- [ ] This becomes the target for validating our own chip

#### 🚪 Gate 5 Criteria (must pass by 2027-01-15)
- ✅ Evaluation PCB assembled and tested (minus Nopal-Sense chip)
- ✅ ESP32 bring-up firmware ready
- ✅ Lab measurement station operational
- ✅ AD5933 baseline Z(ω) measurements documented
- ✅ Bring-up runbook written

**If Gate 5 fails:** PCBs usually take ~2 weeks, so slips are manageable. Biggest risk is packaging vendor delays. Mitigation: identify 2-3 vendors early.

---

### Phase 6 — Chip arrival + Bring-up (2027-01-15 to 2027-02-28)

**Purpose:** Get silicon working. This is the moment of truth.

#### Week 1-2: First power-on
- [ ] Receive packaged chips from PICO
- [ ] Solder 1 chip to evaluation PCB
- [ ] First power-on: measure current in various modes
  - [ ] Sleep mode < 3 µA max (spec)
  - [ ] Normal mode active current
- [ ] Test SPI communication: read VERSION register → expect 0x0100
- [ ] Celebrate first successful SPI transaction 🎉

#### Week 3: Basic sensor reads
- [ ] Test 1-Wire master with DS18B20
- [ ] Test pulse counter with signal generator
- [ ] Test ADC with known reference voltages
- [ ] Log deviations from spec

#### Week 4: IS measurement
- [ ] Connect electrodes to ELEC_A / ELEC_B pins
- [ ] Dip in test impedance (100 Ω, 1 kΩ, 10 kΩ resistors)
- [ ] Validate Z-magnitude at 1 kHz, 100 kHz, 1 MHz
- [ ] Expect within spec ±3% magnitude, ±2° phase
- [ ] If fails: characterize error pattern for possible respin

#### Week 5-6: Soil testing
- [ ] Measure soil samples (same ones AD5933 measured)
- [ ] Compare Nopal-Sense vs AD5933 curves
- [ ] Document discrepancies
- [ ] If healthy vs infected signatures match expectations → IS WORKS

#### 🚪 Gate 6 Criteria (must pass by 2027-02-28)
- ✅ SPI communication functional
- ✅ Sensor interfaces working
- ✅ IS measurement produces interpretable Z(ω)
- ✅ Healthy vs infected soil signatures distinguishable (if not: honest paper still possible)
- ✅ Power consumption within spec

**If Gate 6 fails critically (e.g., chip doesn't power on):** Honest documentation of failure = still publishable. Most first tape-outs have issues. If 90% works, write paper on what worked + what didn't.

---

### Phase 7 — Greenhouse Pilot Validation (2027-03-01 to 2027-06-30)

**Purpose:** **Validate Stage 1 + Stage 2 science** in greenhouse controlled conditions con chips chipathon × 7-10 organismos puros + qPCR ground truth weekly. NOT field deployment directo — eso es bridge state con commercial sensors.

> Esta phase fue reframeada 2026-05-08. Original era "Field Validation". Razón: 5-15 chips chipathon no alcanzan para field deployment de 30+ nodos, pero alcanzan PERFECTO para greenhouse research con 1 chip × 1 organismo. Field continúa con commercial sensor stack hasta v2 chip ready (~2029-2030).
>
> Ver [`../docs/research_program.md`](../docs/research_program.md) para diseño experimental detallado.

#### March 2027: Greenhouse setup + chip bring-up complete
- [ ] 10 chips chipathon empacados disponibles (post Phase 6 bring-up)
- [ ] Greenhouse access confirmed (UdG/ITESO/CINVESTAV partner)
- [ ] Pure cultures secured: P. cinnamomi, P. infestans, Pythium ultimum, Trichoderma harzianum, Aspergillus niger, Bacillus subtilis, controles
- [ ] qPCR partner confirmed (CIATEJ o similar)
- [ ] Lab tech part-time onboarded
- [ ] 30 macetas with avocado seedlings + soil sterilization
- [ ] 4 electrodos acero inox + cables shielded × 10 chip setups

#### April 2027: Inoculation + baseline IS
- [ ] Inocular cada organismo en su maceta dedicada según asignación
  (Chip 1: sterile / Chip 2: Nextipac natural / Chip 3-4: P. cinnamomi
   / Chip 5: P. infestans / Chip 6: Pythium / Chip 7: Trichoderma /
   Chip 8: Aspergillus / Chip 9: Bacillus / Chip 10: spare/cal)
- [ ] Baseline IS sweep × 7 días pre-inoculation
- [ ] qPCR baseline para todas las macetas

#### May 2027: Continuous measurement + wet-dry cycling
- [ ] IS continuous: sweep cada 6h × 30 días (Stage 1 validation)
- [ ] Wet-dry cycling weekly: irrigation Día 1 → IS sweep cada 30 min Día 1-3 → cada 6h Día 4-7 (Stage 2 zoosporogenesis detection)
- [ ] qPCR weekly de todas las macetas
- [ ] Environmental data: T, humidity, light continuous

#### June 2027: Statistical analysis + paper draft
- [ ] Build dataset etiquetado: ~500 MB raw + qPCR pairs
- [ ] Stage 1 analysis: PCA en feature space para sterile vs activos clustering
- [ ] Stage 2 analysis: zoosporogenesis temporal signature post-wet event
- [ ] ML model preliminary: classifier hongo vs oomicete
- [ ] Paper outline: "Multi-Frequency IS for Soil Hyphal Detection: Custom 180nm AFE"

#### 🚪 Gate 7 Criteria (must pass by 2027-06-30)
- ✅ Stage 1 demonstrated: clear separation between sterile vs hyphal-active soil in IS feature space (>90% target probability)
- ✅ Stage 2 evidence: temporal signature of zoosporogenesis detected in oomycete cultures vs absent in fungal cultures (65-80% target)
- ✅ Dataset documentado, etiquetado, reproducible
- ✅ qPCR partner co-authorship secured
- ✅ Paper outline + figures drafted

**If Gate 7 fails (e.g., no Stage 1 separation):** Aún publishable como "negative results in soil IS biological detection at 180nm". Mitigation: ampliar análisis con commercial reference (AD5940) measurements para isolation de chip-specific issues vs fundamental science issues.

---

### Phase 8 — Paper + IEEE Workshop (2027-06-15 to 2027-07-31)

**Purpose:** Publish findings; present at IEEE workshop.

#### Late June - Early July
- [ ] Target venue: IEEE Sensors Journal / Sensors and Actuators B / Computers and Electronics in Agriculture
- [ ] Write paper with CUCBA co-authorship
- [ ] Anthropic acknowledgment (if hackathon tools used in development)

#### Mid-July
- [ ] Submit paper (parallel track: IEEE workshop proceedings)
- [ ] Prepare IEEE workshop presentation
- [ ] Attend IEEE workshop (July 2027)

#### 🚪 Gate 8 Criteria (must pass by 2027-07-31)
- ✅ Paper submitted to target venue
- ✅ Workshop presentation delivered
- ✅ IEEE "Silicon Back" workshop attended
- ✅ Project credentialed: first Mexican agricultural silicon published

**If Gate 8 fails:** Unlikely unless data is catastrophic. Mitigation: re-target to open-access agricultural journal (PeerJ, Frontiers in Plant Science).

---

## 3. Decision log

Historical record of decisions made, with rationale. Append as new decisions emerge.

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-04-10 | Submit PICO Chipathon application | Free fabrication + mentorship + credential | Triggered entire chip project |
| 2026-04-18 | Pivot from 14-module digital to mixed-signal with IS flagship | Digital-only duplicated MCU capabilities; IS is silicon-only capability | Completely changed architecture |
| 2026-04-18 | IS (not Phytophthora scoring) as flagship | Scoring needs to iterate with real data; locking in silicon is error | Scoring stays in VPS |
| 2026-04-18 | Platform-ready philosophy (v1 with bridges, not minimum viable) | v1 must be deployable immediately; every cut feature has external bridge | More complex v1 but scalable |
| 2026-04-18 | 3 fixed frequencies (1k, 100k, 1M Hz) for IS, not programmable sweep | Programmable is v2 risk; 3 points cover regime transitions | Simpler DDS, less area |
| 2026-04-18 | 14-bit ADC (not 12 or 16) | 14-bit hits 3% IS accuracy target in 0.4 mm² | Balance area and precision |
| 2026-04-18 | Shared ADC (IS + sensors, time-multiplexed) | Saves 0.4 mm² | Requires careful scheduling |
| 2026-04-18 | Internal RC oscillator (not crystal) | No external crystal → smaller BOM; DDS freq accuracy is relative | ±5% absolute freq acceptable |
| 2026-04-18 | QFN-40 (not QFN-32) | Enables 4 architectural exports (VREF, CLK, INT, switches) + tamper input | Slightly more area, much more platform |
| 2026-04-18 | External LDO for 1.8V (not on-chip) | Reduces design risk; $0.50 external chip | Small BOM add |
| 2026-04-18 | Simple PUF (no fuzzy extractor in v1) | Fuzzy extractor + ECC too complex for first chip | PUF only for ID, not crypto key |
| 2026-04-18 | Dual clock domain (1 MHz main + 32 kHz sleep) | Sleep clock always-on for wake timer | Need CDC in 2 interfaces |
| 2026-04-18 | Phytophthora v3 scoring stays in VPS | Algorithm must iterate; v4+ with real qPCR data | Chip does not run v3 |
| 2026-04-19 | Move PICO_APPLICATION.md + spi_slave.v to nopal-platform/v1-pico/ | Consolidate after pivot | Single source of truth |
| 2026-04-19 | Delete old nopal-sense/ folder entirely | Git preserves history; working tree clarity matters | Removed 805 lines of obsolete content |

---

## 4. Active risk register

Tracked risks that need ongoing mitigation.

| Risk | Probability | Impact | Owner | Mitigation | Status |
|------|-------------|--------|-------|------------|--------|
| Analog design is first-time for designer | High | High | Designer + Mentor | Explicit request for mixed-signal mentor; conservative topologies | Active — pending mentor assignment |
| TIA auto-ranging fails in corners | Medium | High | Mentor | Conservative design + fall back to 3 gain levels instead of 6 | Active |
| IS doesn't discriminate biofilm in GF180 | Medium | Very High | Designer | Pre-tape-out benchtop validation with AD5933 (Phase 5, Jan 2027) | Active — scheduled |
| Clock accuracy insufficient for IS ratios | Low | Medium | Designer | DDS uses relative freq ratios; absolute drift doesn't affect Z(ω) ratios | Mitigated by design |
| Area overshoots 3 mm² | Medium | Medium | Designer | 30% margin in budget; drop features if necessary | Active |
| Timing closure fails at 1 MHz | Low | Low | Designer | 1 MHz is easy for 180nm; retime if needed | Unlikely |
| Scheduler FSM has bugs in corner cases | Medium | High | Designer | Formal verification (SymbiYosys) for FSM + exhaustive testbench | Planned |
| External bridges don't integrate well in field | Low | Medium | Designer | Validate each bridge on breadboard before tape-out | Planned |
| Missed Sept tape-out deadline | Low | Critical | Designer | Scope reduction plan ready; submit what's clean | Contingency prepared |
| Packaging vendor delays (Oct-Dec 2026) | Medium | Medium | Designer | Identify 2-3 vendors early; overlap with PCB design | Planned |
| qPCR ground truth doesn't correlate with IS | Medium | High | CUCBA + Designer | Even negative result is publishable; frame honestly | Accepted risk |
| CUCBA collaboration formalization delays | Low | Low | Darell | Pre-existing relationship via Biology degree; informal work possible | Ongoing |

---

## 5. Reading order for new collaborators

If someone new joins the project (Salvador, mentor, future teammate), this is the recommended reading order:

1. **`nopal-platform/README.md`** — 10 min. Platform vision and 3-layer architecture.
2. **`nopal-platform/v1-pico/README.md`** — 10 min. v1 technical overview.
3. **`nopal-platform/v1-pico/SPEC_FROZEN.md`** — 30 min. Formal requirements and register map.
4. **`nopal-platform/v1-pico/ARCHITECTURE.md`** — 30 min. Block-level design and rationale.
5. **`nopal-platform/v1-pico/PIN_ASSIGNMENT.md`** — 15 min. Physical interface.
6. **Run `python3 sim/golden_model.py --test`** — 2 min. See working Python reference.
7. **Run `python3 sim/golden_model.py --is-demo`** — 2 min. See IS discrimination in action.
8. **`nopal-platform/v1-pico/MENTOR_BRIEFING.md`** — 5 min. What we're asking the mentor.
9. **`nopal-platform/v1-pico/ROADMAP.md` (this doc)** — 20 min. Where we are + where we're going.
10. **`nopal-platform/v1-pico/PICO_APPLICATION.md`** — 10 min. Historical context (original submission).

Total onboarding time: ~2 hours to read all + 30 min to run simulations.

---

## 6. Weekly cadence (during active development)

Suggested rhythm once Phase 1 starts:

### Monday
- Review prior week's deliverables
- Plan current week's specific tasks
- Update ROADMAP.md checkboxes

### Tuesday-Thursday
- Focused work on current week's deliverables
- Commit at least once daily
- Run tests before committing

### Friday
- Mentor 1-on-1 (typically 1 hour video call)
- Review progress vs plan
- Identify blockers
- Update risk register if new risks emerge

### Sunday
- Write short weekly update in repo (optional `WEEKLY.md`)
- Plan Monday ahead

---

## 7. Success definition

Nopal-Sense v1 is successful if:

### Minimum success (acceptable)
- ✅ Tape-out completed September 2026
- ✅ Chips received January 2027
- ✅ Basic SPI communication works
- ✅ Paper submitted (any venue, any result)

### Target success (expected)
- ✅ All above PLUS:
- ✅ IS measurement produces interpretable Z(ω)
- ✅ IEEE workshop attended with silicon demo
- ✅ CUCBA co-authored paper in Q2+ journal

### Stretch success (ambitious)
- ✅ All above PLUS:
- ✅ IS clearly discriminates healthy vs infected soil
- ✅ Publication in Q1 journal (IEEE Sensors J, S&A B, C&EA)
- ✅ v2 commercial design initiated with IP strategy
- ✅ Grants secured (NLnet, NGI, SECIHTI, FODECIJAL)

---

## 8. Cross-project dependencies

Nopal-Sense depends on and interfaces with:

- **Zafra-AgTech platform** (github.com/Jefemaestro33/Zafra-Agtech)
  - Backend must accept IS payloads (additive to existing sensor data)
  - Dashboard may need IS visualization view (for v4 rollout)
- **Zafra-CUCBA convenio** (Convenio_Zafra-2.pdf)
  - Provides qPCR ground truth for Gate 7 field validation
  - Provides scientific legitimacy for paper
- **Hackathon project (AgroClaude)** if selected
  - Does NOT block Nopal-Sense timeline
  - Could integrate with chip (if won) but not critical path

---

## 9. Budget (informational — not committed)

Tracked in separate financial doc. Here is directional:

| Category | Approximate cost |
|----------|------------------|
| PICO tape-out | $0 (IEEE pays) |
| PCB design + fab (10 boards) | $200-400 MXN |
| ESP32 + LoRa modules (10) | $2,400 MXN |
| Sensors + probes (10 sets) | $1,500 MXN |
| AD5933 baseline kit | $2,000 MXN |
| Packaging (wire-bond 10 chips) | $4,000 MXN |
| Lab equipment (oscilloscope rental, etc.) | $3,000 MXN |
| Conference attendance (IEEE 2027) | ~$15,000 MXN if in-person |
| **Total directional** | **~$28K MXN (~$1.5K USD)** |

Excludes time investment.

---

## 10. Document maintenance

This ROADMAP.md is **alive**. Update it:

- Weekly: checkbox completion for active phase
- Monthly: review risk register; add/update
- After major decisions: append to decision log
- After each gate: mark gate passed/failed with date and notes

Keep this doc under version control. Commit updates with descriptive messages.

---

## Appendix A: Related documents

- [`README.md`](./README.md) — v1 technical overview
- [`SPEC_FROZEN.md`](./SPEC_FROZEN.md) — formal requirements
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — design rationale
- [`PIN_ASSIGNMENT.md`](./PIN_ASSIGNMENT.md) — physical interface
- [`MENTOR_BRIEFING.md`](./MENTOR_BRIEFING.md) — mentor intro
- [`PICO_APPLICATION.md`](./PICO_APPLICATION.md) — historical submission
- [`../README.md`](../README.md) — platform vision
- [`../v2-commercial/README.md`](../v2-commercial/README.md) — v2 roadmap

## Appendix B: External resources

- [PICO Chipathon 2026](https://sscs.ieee.org/technical-committees/tc-ose/sscs-pico-design-contest/)
- [GF180MCU PDK](https://github.com/google/gf180mcu-pdk)
- [OpenLane digital flow](https://github.com/The-OpenROAD-Project/OpenLane)
- [cocotb verification framework](https://docs.cocotb.org/)
- [Zafra-AgTech repo](https://github.com/Jefemaestro33/Zafra-Agtech) (private)
- [Convenio CUCBA-UdG](../../../Convenio_Zafra-2.pdf) (local desktop, not committed)

---

**Last updated:** 2026-04-19
**Next scheduled review:** 2026-05-08 (after Phase 1 Week 1)
