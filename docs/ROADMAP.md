# Nopal-Sense Roadmap

This document is the public roadmap for the Nopal-Sense v1 chip collateral.
It is intentionally implementation-focused: private research strategy,
datasets, pilots, and operator-side planning live outside this repository.

## Current State

As of commit `fd81525`, the public repository has closed Phase 1b for the
digital spine.

Baseline:

- Public repo: `~/nopal-sense`
- Active design package: `v1-pico/`
- RTL root: `v1-pico/rtl/`
- Test root: `v1-pico/tb/`
- Digital regression: 19 Icarus testbench targets, 206 PASS assertions, 0 FAIL
- Python model: `v1-pico/sim/golden_model.py --test` passes 8/8

Integrated digital spine:

- Host SPI register access.
- Scheduler / mode control / wake timer.
- IS control path: SPI trigger -> scheduler -> IS FSM -> CORDIC -> Z registers.
- Sensor path: raw ADC MUX -> calibration -> per-channel moving average -> sensor registers.
- Alert path evaluated on real calibrated and averaged sensor data.
- ADC timeout handling for IS and sensor reads.
- MISO pad output-enable gated by chip-select.

Still explicit stubs or placeholders:

- `pulse_counter` is unit-tested but not wired into `EC_FREQ`.
- `crc16` is unit-tested but not used by an integrated payload path.
- `por_bod` is unit-tested but not integrated into reset strategy.
- External SPI / I2C / 1-Wire bridge modules are instantiated but idle.
- `puf` is a placeholder constant ID, not a real die-unique PUF.
- Analog/AMS blocks are not implemented.

## How To Resume Work

For any future implementation session:

1. Work from `~/nopal-sense`.
2. Confirm the public repo is clean:

   ```bash
   git status --short --branch
   ```

3. Read these files before changing RTL:

   - `README.md`
   - `v1-pico/README.md`
   - `docs/ROADMAP.md`
   - `v1-pico/rtl/nopal_sense_top.v`
   - `v1-pico/rtl/sensor_read_controller.v`
   - `v1-pico/tb/tb_nopal_top.v`

4. Run the baseline checks before and after changes:

   ```bash
   cd v1-pico/tb
   make clean
   make all
   python3 ../sim/golden_model.py --test
   ```

5. Keep each Phase 1c item test-first, locally verified, documented, and
   committed as a small closure slice.

## Phase 1a - Digital Spine Base

Status: closed.

Scope:

- SPI slave.
- Register bank.
- Scheduler.
- Wake timer.
- Sleep control.
- DDS control.
- IS FSM.
- CORDIC.
- Alert engine.
- PUF placeholder.
- External bus primitive blocks.
- Workshop wrapper (`chip_core.sv`).
- Module-level regression.

Phase 1a established the base digital control plane and unit-level coverage.

## Phase 1b - Digital Integration Hardening

Status: closed in the public repo.

Closure commits:

- `c8d6b6e` - Complete Phase 1b sensor pipeline integration
- `19ea656` - Document Phase 1b closure and Phase 1c backlog
- `a19e827` - Sync PPR submission collateral to instantiated-module count
- `fd81525` - Fix testbench count (19, not 20) and golden-model wording

Closed scope:

- MISO is two-state inside the core; pad high-Z is controlled through output-enable.
- MISO pad output-enable is gated by SPI chip-select.
- `is_fsm` has an ADC watchdog and raises STATUS.error instead of hanging.
- `sensor_read_controller` is integrated.
- Shared ADC arbitration between IS and sensor reads is integrated.
- Sensor pipeline is integrated: raw ADC -> calibration -> moving average -> registers.
- Calibration saturates to the Q8.8 rail instead of wrapping.
- Sensor partial/faulted reads do not commit mixed snapshots.
- Alert engine consumes real sensor pipeline data.
- Top-level behavioral ADC test exercises IS sweep, sensor pipeline, alert path, and fault paths.

Phase 1b does not include the analog/AMS implementation or the remaining
Phase 1c digital closure decisions.

## Phase 1c - Digital Closure / Freeze Prep

Status: next phase, not started.

Goal:

Close or explicitly defer the remaining digital blocks before digital freeze
and the first serious synthesis pass.

Recommended order:

1. **Pulse counter + EC path**
   - Integrate `pulse_counter.v`.
   - Wire the `pulse_in` pad into the counter path.
   - Feed `EC_FREQ` through `sensor_read_controller`.
   - Add top-level coverage proving `EC_FREQ` is no longer tied to zero.

2. **POR/BOD reset strategy**
   - Decide whether `por_bod.v` is integrated on-chip for v1.
   - If not integrated, document reliance on external `RST_N` RC behavior.
   - Keep the decision tied to `PIN_ASSIGNMENT.md` GL-014.

3. **Bridge controller**
   - Add `bridge_controller.v`.
   - Decode register/trigger intent into the external SPI, I2C, and 1-Wire primitives.
   - Preserve the current idle behavior until explicitly commanded.

4. **CRC16 integration decision**
   - Integrate `crc16.v` only if there is a concrete payload path.
   - Candidate paths: bridge payload integrity, debug/log records, or firmware-visible transaction checks.
   - Otherwise document it as deferred rather than wiring it without purpose.

5. **PUF decision**
   - Decide between a real uninitialized SRAM macro path or accepting the current placeholder ID for v1.
   - If placeholder remains, document that IDs are not die-unique.

6. **Debug opcode 0xDE**
   - Implement only if it materially helps bring-up or validation.
   - Otherwise defer explicitly.

7. **LibreLane synthesis smoke**
   - Run a first synthesis/layout feasibility pass.
   - Capture unsupported constructs, warnings, area, clock/reset assumptions, and any required RTL cleanup.

Phase 1c exit criteria:

- Remaining digital blocks are integrated or explicitly deferred.
- README and this roadmap match the actual netlist.
- `make clean && make all` passes.
- `golden_model.py --test` passes or any model limitations are documented.
- Synthesis smoke findings are either fixed or tracked.
- The public repo is clean and synchronized with `origin/main`.

## Phase 2 - Analog / AMS

Status: not started.

Goal:

Implement and verify the mixed-signal measurement chain needed by the digital
interfaces already present in `nopal_sense_top.v`.

Expected scope:

- Bandgap/reference.
- DAC or stimulus generator analog path.
- Output buffer / electrode drive path.
- TIA / front-end receive path.
- I/Q mixer or equivalent demodulation support.
- Low-pass filtering.
- Shared SAR ADC and ADC controller contract.
- Analog MUX.
- AMS co-simulation against the digital control interface.
- Corners and basic robustness checks.

Phase 2 is the main path from a credible digital vehicle to a true
mixed-signal chip.

## Phase 3 - Tape-Out Package / System Validation

Status: future.

Goal:

Prepare the final review and tape-out collateral, then support bring-up and
post-silicon validation.

Expected scope:

- Final padring and top-level integration review.
- DRC/LVS/STA closure.
- Final Chip Review collateral.
- Firmware/ESP32 bring-up plan.
- Lab test plan and register-access scripts.
- Post-silicon measurement plan for IS and sensor paths.
- Known limitations and deferred-feature documentation.

## Public Scope Boundary

This repository tracks public chip collateral. It should not contain private
operator strategy, private datasets, biological validation records, or
non-public partner details. Those belong in the private research notebook.
