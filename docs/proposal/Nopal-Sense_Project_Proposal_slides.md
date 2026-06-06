# Nopal-Sense

**Mixed-Signal Soil Impedance Spectroscopy Hub**  
IEEE SSCS PICO Open-Source Chipathon 2026  
Week 24 Project Proposal Review - June 12, 2026

**Team members:**  
Leader: Ernest Zermeño (@Jefemaestro33)  
Individual Track B participant

**Contact email:**  
ernest@zlabstudio.com

**Track:**  
B - Circuits for Sensors  
Secondary relevance: D - AI/LLM-assisted audit and documentation workflow

# Project Information

**Goal (2 sentences)**  
Nopal-Sense aims to tape out a low-power mixed-signal soil-impedance spectroscopy ASIC for agricultural deployments. The chip generates controlled multi-frequency excitation through soil electrodes, measures the root-zone response, and exposes calibrated data through a simple SPI-controlled hub.

**Design - High Level Proposal (2-3 sentences + image)**  
The differentiating block is the soil impedance spectroscopy path: DDS/DAC excitation, electrode interface, TIA/IQ readout, filtering, and shared SAR ADC. Around it, v1 adds SPI registers, scheduler, alerts, and bridge interfaces; digital RTL is integrated under `v1-pico/` with 185/185 Icarus assertions passing. The tapeout scope is the spectroscopy measurement platform; long-term stress/root-disease inference belongs to off-chip datasets, software, and AI models after validation.

**Application (1 sentence)**  
Low-cost agricultural soil impedance spectroscopy for irrigation, salinity, and root-zone condition tracking, with a future data path toward software models for validated fungal/oomycete-related stress patterns.

**References**  
SSCS Chipathon 2026 repo and guidelines; Nopal-Sense public repo/spec/architecture; Kelleners et al., 2009; Samouelian et al., 2005.

![](assets/nopal_sense_system.svg)

# Team Background

**Academic Experience**  
Ernest Zermeño - Biology background, currently working in bioinformatics research involving CRISPR and experimental biology. Technical interests include computational biology, data analysis, embedded systems, and measurement tools for biological and agricultural systems.

**Work Experience**  
Software and applied technology work through zlabstudio. Previous work includes exploring FHE-based software development and building practical software systems, with a focus on turning technical ideas into usable tools.

# Questions, Suggestions, Doubts?

- Is the v1 must-work scope realistic if limited to soil impedance spectroscopy AFE, shared SAR ADC, SPI register access, and low-power scheduling?
- Should the ADC be a custom SAR implementation in v1, or should Nopal-Sense reuse an existing open-source/reference ADC to reduce schedule risk?
- What electrode protection, ESD strategy, and analog pad usage are recommended for soil probes connected outside the chip package?
- Are 10 kHz, 30 kHz, and 100 kHz acceptable first-tapeout frequencies for root-zone impedance, or should the top frequency be reduced for robustness?
- What minimum AMS validation evidence is expected by the July block and top-level simulation reviews?
