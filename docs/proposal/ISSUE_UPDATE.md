# Proposed Official Issue Update

Use this text to update the public Chipathon issue after the proposal deck is
published in the repository.

```markdown
## Project Proposal

- Proposal text: https://github.com/Jefemaestro33/nopal-sense/blob/main/docs/proposal/Nopal-Sense_Project_Proposal.md
- Proposal deck: https://github.com/Jefemaestro33/nopal-sense/blob/main/docs/proposal/Nopal-Sense_Project_Proposal.pptx
- PDF preview: https://github.com/Jefemaestro33/nopal-sense/blob/main/docs/proposal/Nopal-Sense_Project_Proposal.pdf
- Slide source: https://github.com/Jefemaestro33/nopal-sense/blob/main/docs/proposal/Nopal-Sense_Project_Proposal_slides.md

## Week 24 Proposal Review Scope

Nopal-Sense v1 is scoped as a low-power mixed-signal soil/root-zone impedance
spectroscopy hub for agricultural deployments. The target medium is soil/root
zone through external electrodes, not plant tissue EIS. The differentiating
silicon block is the DDS/DAC excitation, electrode interface, TIA/IQ readout,
filtering, and shared SAR ADC path that enables repeatable multi-frequency soil
response measurements. The v1 silicon goal is measurement and control
infrastructure, not direct pathogen diagnosis. The long-term product goal is to
use constant validated measurements to support off-chip software and AI models
for root-zone stress and disease patterns, including fungal or oomycete-related
signatures after controlled validation.

## Current Public Progress

- Public GF180MCU project repository synchronized at:
  https://github.com/Jefemaestro33/nopal-sense
- Frozen public spec, architecture, and workshop-slot pin assignment under
  `v1-pico/`.
- 18 functional RTL modules plus top-level integration and workshop wrapper.
- 185/185 Icarus regression assertions passing.
- P0 digital integration audit findings fixed in RTL.

## Remaining Near-Term Milestones

- Confirm proposal deck for June 12 Project Proposal Review.
- Add `bridge_controller.v` for external SPI / I2C / 1-Wire trigger decoding.
- Add ADC and sensor behavioral stubs for fuller top-level verification.
- Expand top-level integration coverage beyond the current audited paths.
- Begin analog AFE planning for DDS/DAC, buffer, TIA, I/Q mixer, shared SAR ADC,
  and bandgap/reference.
```
