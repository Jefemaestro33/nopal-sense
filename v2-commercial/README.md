# Nopal-Sense v2 (Producto Comercial)

**Chip de producción comercial, post-validación v1 en campo.**

Target: 2028-2029 tape-out, volumen 10,000+ unidades/año, precio $5-8 USD/chip.

---

## Filosofía del v2

v2 NO es "v1 con más cosas." Es **la segunda generación informada por datos reales** que v1 generó durante 12-18 meses de validación en campo.

Principios:
1. **Evidencia empírica sobre hipótesis:** cada feature se justifica con data real de v1
2. **Integración agresiva:** lo que v1 apoyaba con bridges externos, v2 lo integra
3. **Proceso más moderno:** migración a GF 130nm o 110nm para área + consumo
4. **Producto comercial:** no research chip, producto para deploy masivo

---

## Agrega sobre v1

### Features promovidas de bridge a hardware integrado

Cada bridge de v1 se convierte en bloque nativo en v2:

| Bridge v1 | Hardware v2 | Mejora |
|-----------|-------------|--------|
| I2C bit-banged | Hardware I2C master (400 kHz-1 MHz) | 10× más rápido, menos CPU |
| FeRAM externa SPI | FeRAM 64 KB on-die | -1 chip externo, -$4 BOM |
| PUF simple + ATECC608 | Fuzzy extractor + AES + ECDSA integrados | -1 chip, crypto genuino |
| Reed switch + TAMPER pin | Tamper sofisticado (V, F, PUF drift) | Detección multi-capa |
| DS28E07 probe IDs | Protocolo propio smart probe bus | Plug-and-play real |
| 4 modos + firmware scheduler | Scheduler adaptativo completo | Autónomo, menos wake ESP32 |
| Registros + firmware analiza | Auto-diagnóstico autónomo | Sin firmware intervention |
| 3 frecuencias IS fijas | Barrido programable 100 Hz – 10 MHz | Research-grade measurements |
| EN_LDO + LDO externo | LDOs on-chip | -$0.50 BOM, menos componentes |
| SPI debug mode | JTAG formal + boundary scan | Debug industrial |
| ML en VPS | ML accelerator para pattern matching | Inferencia on-chip <1 ms |
| Firmware secure boot | Secure boot completo en silicio | ROM inmutable, resistencia a tampering |

### Nuevas capabilities v2 (no existían en v1)

| Feature | Justificación |
|---------|---------------|
| **Barrido IS fino (100 puntos programables)** | Modelado electroquímico avanzado, patentable |
| **Detección multi-patógeno via ML on-chip** | Con datos v1, entrenas modelos para P. cinnamomi, Fusarium, otros |
| **Wake-on-event inteligente** | Despertar por firmas específicas, no solo thresholds |
| **Comunicación cifrada extremo-a-extremo** | Entre chip y VPS, sin depender de ESP32 |
| **Self-calibration routine** | Auto-calibración en campo sin intervención humana |
| **Multi-probe management (hasta 16)** | Un chip controla múltiples probes a diferentes profundidades/locaciones |
| **OTA del chip mismo** | Actualizar firmware de controladores internos del chip |

---

## Especificaciones técnicas target

| Parámetro | v1 | v2 |
|-----------|-----|-----|
| Proceso | GF180MCU 180nm | GF 130nm o 110nm |
| Área estimada | ~2.7 mm² | ~6-7 mm² |
| Package | QFN-40 | QFN-64 o BGA-81 |
| Consumo sleep | <1 µA | <100 nA |
| Consumo activo | ~2 mA × 100 ms | ~1 mA × 50 ms (50% menos) |
| Rango IS | 3 frecuencias fijas | Barrido 100 Hz – 10 MHz, 100 puntos |
| Memoria on-die | 32 registros + SRAM | 32 registros + SRAM + 64 KB FeRAM |
| Seguridad | PUF simple + external crypto | Fuzzy PUF + AES + ECDSA integrados |
| Interfaces | SPI, 1-Wire, bit-bang I2C | SPI, 1-Wire, HW I2C, Smart Probe Bus |
| ML on-chip | ❌ | ✅ pattern matching + classifier |
| Update firmware | ❌ | ✅ OTA chip firmware |

---

## Estrategia de área y proceso

**¿Por qué migrar a 130nm/110nm?**

v1 en 180nm: ~2.7 mm² es cómodo para GF180MCU.
v2 con todas las features: ~6-7 mm² en 180nm sería caro y consumiría más energía.

Migración a 130nm:
- Reduce área ~40% (misma funcionalidad en 4 mm²)
- Reduce potencia dinámica ~50%
- Permite más features en misma área
- PDK IHP SG13G2 (open-source) disponible para mixed-signal

Migración a 110nm (opción más agresiva):
- Reduce área ~60%
- Mejor para ML accelerator
- Requiere foundry commercial (TSMC, SMIC)

**Decisión pendiente a 2027** basada en lecciones v1 + disponibilidad de shuttle.

---

## Validación requerida antes de tape-out v2

No nos tape-outamos v2 hasta confirmar:

1. **IS funciona como hipotetizamos en v1** (correlación con qPCR > 0.5)
2. **Dataset pareado robusto** (mínimo 500 puntos sensor + qPCR + yield)
3. **Modelo v4 del algoritmo Zafra** entrenado y validado
4. **Demand signal comercial** (al menos 3 productores dispuestos a pagar)
5. **Partnership scientific** (al menos 1 universidad co-autora en paper)

Sin estas 5 condiciones, v2 se posterga — no tape-outamos por orgullo, tape-outamos con evidencia.

---

## Modelo de negocio del chip v2

### B2C (productores directos)
- Nodo completo con chip v2: $25-30 USD BOM
- Venta en paquete con servicio Zafra-AgTech
- Sin costo upfront (revenue share del servicio)

### B2B (licensing)
- Otros agtech companies compran el chip
- $8-12 USD/chip a volumen
- Potencial: 100K-1M unidades/año si licencia a integradores

### B2G (gobierno, investigación)
- Universidades, centros de investigación, programas gubernamentales
- Precio premium con soporte técnico
- Demos de vigilancia fitosanitaria a nivel regional

---

## IP strategy para v2

### Patentes a filar (antes de tape-out v2)
1. **Método de detección multi-frecuencia de patógenos de suelo** (core patent)
2. **Smart probe bus protocol** (protocolo + implementación)
3. **Fuzzy extractor específico para agricultural IoT** (seguridad)
4. **Sistema integrado sensor + chip + cloud** (sistema)

### Trade secrets (no patent)
- Coeficientes de calibración específicos por región/suelo
- Dataset pareado (sensor + qPCR + yield)
- Modelos ML entrenados

### Open source (requerido por PICO si reutilizamos)
- Verilog de bloques derivados de v1 → Apache 2.0
- Specs y documentación → CC BY-SA 4.0

---

## Timeline v2

```
2027 (chips v1 en mano):
  Q1: Validación silicon v1 en lab
  Q2-Q3: Bring-up y primeras medidas en campo
  Q4: Dataset inicial + preparación de v2 spec

2028 (diseño v2):
  Q1: Spec freeze v2 basado en data real
  Q2: RTL + analog design
  Q3: Verification + layout
  Q4: Tape-out v2

2029 (producción):
  Q1: Chips recibidos, bring-up
  Q2: Package qualification
  Q3: Mass production ramp
  Q4: Comercialización B2C + B2B

2030+:
  Escala a 10K-100K unidades
  Expansión geográfica (Michoacán, Colombia, Perú)
  Expansión de cultivos (cítricos, berries, hortalizas)
```

---

## Riesgos y contingencias

### Riesgo: v1 muestra que IS no funciona como hipotetizamos
**Contingencia:** v2 se rediseña como chip de consolidación (sin flagship IS). Aún es producto viable por el ahorro BOM + consolidación. Perdemos el moat de "detección directa" pero mantenemos ventajas estructurales.

### Riesgo: Competidores copian la tesis antes de v2
**Contingencia:** v1 nos da 2-3 años de ventaja. Dataset único + relación con productores + iteración rápida compensan replicación hardware.

### Riesgo: Proceso 130nm/110nm no disponible gratuitamente
**Contingencia:** wafer.space o chipIgnite en SKY130 (130nm). ~$15K USD por tape-out, manejable como empresa.

### Riesgo: Capital insuficiente para tape-out comercial
**Contingencia:** Revenue de Zafra-AgTech piloto + grants (NLnet, NGI, CONACyT) + potencial ronda seed.

---

## Decisiones pendientes (para 2027-2028)

Estas se toman con datos reales, no ahora:

1. **Proceso:** ¿130nm o 110nm?
2. **Package:** ¿QFN-64 o BGA-81?
3. **Volumen inicial:** ¿1K o 10K?
4. **Expansion de features:** ¿incluir MEMS? ¿RF on-chip?
5. **Partnership de fab:** ¿GF, SMIC, TSMC?
6. **Licensing strategy:** ¿exclusivo a Zafra o open licensing?

---

## Archivos (pendientes de creación post-v1)

- [ ] `SPEC_v2.md` — Especificación basada en lecciones v1
- [ ] `LESSONS_FROM_V1.md` — Qué aprendimos, qué cambia
- [ ] `PATENT_FILINGS.md` — Tracker de patentes
- [ ] `BUSINESS_PLAN.md` — Modelo comercial detallado
- [ ] `MANUFACTURING_PLAN.md` — Foundry, packaging, test

---

## Relación con v1

Este README es aspiracional. v1 debe funcionar antes de que v2 sea siquiera considerado seriamente.

**Regla de oro:** No invertimos capital en v2 hasta tener:
- Chips v1 funcionando eléctricamente
- Datos de campo validando la tesis IS
- Al menos una publicación científica

Si v1 demuestra que la tesis es incorrecta, v2 se rediseña fundamentalmente. Eso no es fallo — es ciencia.

---

**Para diseño actual actívo, ver [`../v1-pico/`](../v1-pico/).**
