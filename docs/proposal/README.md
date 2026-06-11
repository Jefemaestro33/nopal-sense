# Nopal-Sense Proposal Package

This folder contains the proposal material for the SSCS Chipathon 2026 Week 24
Project Proposal Review on June 12, 2026.

## Files

| File | Purpose |
|---|---|
| `Nopal-Sense_Project_Proposal.md` | Full proposal text for review and iteration |
| `Nopal-Sense_Project_Proposal_slides.md` | Four-slide source matching the official Chipathon proposal template |
| `Nopal-Sense_Project_Proposal.pptx` | Generated PowerPoint deck, if built with Pandoc |
| `Nopal-Sense_Project_Proposal.pdf` | Generated PDF preview of the proposal text |
| `ISSUE_UPDATE.md` | Public issue update text to use after publishing the deck |
| `assets/nopal_sense_chip_architecture.png` | Rendered ASIC functional architecture diagram used by the PPTX/PDF source |
| `assets/nopal_sense_chip_architecture.svg` | Editable source for the ASIC functional architecture diagram |
| `assets/nopal_sense_system.svg` | Earlier system block diagram kept as reference material |

## Build the PPTX Deck

From the repository root:

```bash
pandoc docs/proposal/Nopal-Sense_Project_Proposal_slides.md \
  --resource-path=docs/proposal \
  --reference-doc=/Users/darellplascencia/sscs-chipathon-2026/resources/documents/template_2026_ChipathonProposals.pptx \
  -o docs/proposal/Nopal-Sense_Project_Proposal.pptx
```

Pandoc may warn that some layout names from the official template are not
standard Pandoc layout names. The generated deck is still usable; final visual
polish can be done in PowerPoint/Keynote before public submission.

## Publication Checklist

- Confirm the proposal deck content.
- Generate the `.pptx` deck.
- Review the slide text for timing and scope.
- Commit and push the proposal files.
- Update the official issue with the links in `ISSUE_UPDATE.md`.
- Submit the weekly Chipathon report form when available.
