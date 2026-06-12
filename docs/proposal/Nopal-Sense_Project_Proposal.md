# Nopal-Sense Project Proposal

**Event:** IEEE SSCS PICO Open-Source Chipathon 2026  
**Review:** Week 24 Project Proposal Review, June 12, 2026  
**Track:** B - Circuits for Sensors  
**Secondary relevance:** D - AI/LLM-assisted design workflow, for audit and documentation support only  
**Repository:** https://github.com/Jefemaestro33/nopal-sense  
**Public issue:** https://github.com/sscs-ose/sscs-chipathon-2026/issues/16

This document is the reviewable text version of the Nopal-Sense proposal. The
slide source in this folder maps the same content to the official four-slide
Chipathon proposal template.

## 1. Team Information

**Team name:** Nopal-Sense

| Role | Name | GitHub | Notes |
|---|---|---|---|
| Design lead | Ernest Zermeño | @Jefemaestro33 | Universidad de Guadalajara; individual Track B participant |

**Contact email:** ernest@zlabstudio.com

## 2. Project Information

### Goal

Nopal-Sense aims to tape out a low-power mixed-signal ASIC for repeatable
soil/root-zone impedance spectroscopy using buried electrodes. The research goal
is to generate dense, calibrated datasets to test whether root-zone electrical
patterns can indicate abnormal biological activity, including fungal or
oomycete-related signals after controlled validation.

### High-Level Design Proposal

The chip provides programmable AC excitation, electrode-interface readout,
filtering, ADC access, and SPI-configurable control. Around the impedance path,
the architecture includes autonomous low-power frequency sweeps, synchronized
moisture/temperature context, and electrode contact/health checks to flag
unreliable soil data caused by poor contact, corrosion, polarization, or cable
faults.

V1 is a measurement and data-generation platform, not a pathogen-diagnosis
chip. Commercial impedance AFEs such as AD5940/ADuCM355 are useful baselines;
Nopal-Sense focuses on the soil-specific embedded layer: buried electrodes,
environmental confounders, contact quality, low-power operation, and
longitudinal datasets for later biological validation.

![Nopal-Sense ASIC functional architecture](assets/nopal_sense_chip_architecture.png)

### Application

Low-cost agricultural root-zone monitoring for irrigation, salinity, and
abnormal-condition screening, with a long-term path toward validated
fungal/oomycete pattern detection from longitudinal soil impedance datasets.

### Long-Term Product Vision

Prior work shows several pieces of this direction are viable: low-cost soil
sensor data can classify avocado stress and Phytophthora root rot patterns,
Phytophthora zoospores can produce impedance-detectable events in controlled
microfluidics, and impedance methods can phenotype roots and disease effects in
opaque growth media. Nopal-Sense does not claim those results are already solved
in open agricultural soil. Instead, the chip is intended to make repeatable
root-zone impedance measurements cheap and standardized enough to collect the
datasets needed to test that harder question.

### Current Public Progress

- Public GF180MCU project repository created and synchronized with GitHub.
- Frozen public v1 specification, architecture, and 88-pin workshop-slot pin
  assignment are available in `v1-pico/`.
- 18 functional RTL modules are implemented and module-tested; 13 are currently
  instantiated in the top-level digital integration, plus the workshop wrapper.
- Current Icarus module/top regression passes locally.
- P0 digital integration audit findings have been fixed in RTL.

### Remaining Milestones Before Proposal Review

- Publish the proposal deck and link it from the official Chipathon issue.
- Confirm any additional team/collaboration entries.
- Keep the public scope precise: soil/root-zone measurement hub, not plant
  tissue EIS and not immediate pathogen identification.

### Remaining Milestones After Proposal Review

- Add `bridge_controller.v` to decode trigger registers into external SPI, I2C,
  and 1-Wire transactions.
- Add ADC and sensor behavioral stubs for top-level verification.
- Integrate or explicitly defer standalone support blocks that are currently
  module-tested but outside the top-level netlist.
- Expand top-level integration coverage beyond the current audited paths.
- Begin analog AFE planning for DDS/DAC, buffer, TIA, I/Q mixer, low-pass
  filtering, shared SAR ADC, and bandgap/reference.
- Prepare schematic-level review material for the July 3 Schematic Review.

### References

- IEEE SSCS Chipathon 2026 repository and participation guidelines:
  https://github.com/sscs-ose/sscs-chipathon-2026
- Nopal-Sense public repository:
  https://github.com/Jefemaestro33/nopal-sense
- Nopal-Sense v1 frozen specification:
  https://github.com/Jefemaestro33/nopal-sense/blob/main/v1-pico/SPEC_FROZEN.md
- Nopal-Sense v1 architecture:
  https://github.com/Jefemaestro33/nopal-sense/blob/main/v1-pico/ARCHITECTURE.md
- Bukhari et al., "Low-Cost Sensing and Classification for Early Stress and
  Disease Detection in Avocado Plants", UC Riverside, arXiv:2508.13379, 2025:
  https://arxiv.org/abs/2508.13379
- Zhang et al., "Microfluidic Biosensors for the Detection of Motile Plant
  Zoospores", Biosensors, 2025:
  https://www.mdpi.com/2079-6374/15/3/131
- Corona-Lopez et al., "Electrical impedance tomography as a tool for
  phenotyping plant roots", Plant Methods, 2019:
  https://link.springer.com/article/10.1186/s13007-019-0438-4
- Settimi, "Performance of Electrical Spectroscopy using a Resper Probe to
  Measure the Salinity and Water Content of Concrete or Terrestrial Soil",
  Annals of Geophysics / arXiv, 2011:
  https://arxiv.org/abs/1006.4307
- Analog Devices, "AD5940/AD5941 High Precision, Impedance, and Electrochemical
  Front End", Data Sheet:
  https://www.analog.com/media/en/technical-documentation/data-sheets/ad5940-5941.pdf
- Analog Devices, "ADuCM355 Precision Analog Microcontroller with Chemical
  Sensor Interface", Data Sheet:
  https://www.analog.com/media/en/technical-documentation/data-sheets/aducm355.pdf
- Samouelian et al., "Electrical resistivity survey in soil science: a review",
  Soil and Tillage Research, 2005:
  https://doi.org/10.1016/j.still.2004.10.004

## 3. Team Background

### Academic and Technical Experience

- Ernest Zermeño has a biology background and is currently working in
  bioinformatics research involving CRISPR and experimental biology.
- Technical interests include computational biology, data analysis, embedded
  systems, and measurement tools for biological and agricultural systems.
- This background motivates the focus on practical soil/root-zone measurements
  rather than a generic sensor interface.

### Work and Application Experience

- Software and applied technology work through zlabstudio.
- Previous work includes exploring FHE-based software development and building
  practical software systems.
- Focused on turning technical ideas into usable tools, especially where
  biology, software, data, and measurement systems overlap.

## 4. Questions, Suggestions, and Doubts

1. What is the recommended must-work scope for v1 if the full architecture is
   too large for the tapeout schedule?
2. Should v1 reuse an existing open-source/reference SAR ADC instead of a
   custom ADC design to reduce schedule risk?
3. What electrode protection, ESD strategy, and analog pad usage are recommended
   for soil probes connected outside the chip package?
4. What minimum AMS validation evidence is expected for the July block-level and
   top-level simulation reviews?
