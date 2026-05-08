# Business Model — Nopal-Sense / Zafra-AgTech

**Versión:** 1.0 (2026-05-08)
**Status:** Active framework
**Owner:** Ernest Darell Zermeño Plascencia

Este documento explica el modelo de negocio de Nopal-Sense y por qué la decisión de **vertical integration** (NO vender el chip al mercado abierto) es estratégicamente la correcta.

---

## 1. La decisión central: vertical integration

**Zafra-AgTech NO vende Nopal-Sense al mercado.** Lo usa internamente como componente diferenciador del servicio AgTech.

Es la diferencia entre dos modelos completamente distintos:

```
MODELO A (vender chips):                    MODELO B (vertical integration):
                                            
Chip Co.                                    Zafra-AgTech (este modelo)
├── Chip design                             ├── Chip design (CapEx)
├── Chip production                         ├── Chip production (CapEx)
├── Sales team                              ├── Node manufacturing
├── Customer support       vs               ├── Field deployment
├── Datasheets/AppNotes                     ├── Data collection
└── Compete vs AD/TI/MAXIM                  ├── ML model (qPCR-trained)
                                            └── Service revenue
                                            
Revenue: $X/chip × volume                   Revenue: $X/ha/año × volume
Margin: 30-50% típico                       Margin: 70-90% típico
Moat: chip features                         Moat: chip + data + algoritmo
                                            
Ejemplo: Analog Devices, TI                 Ejemplo: Apple, Climate Corp
                                            (Climate fue $1B exit a Bayer)
```

**Apple no vende M-series chips al mercado. Los usa.** Climate Corp no vendía chips, vendía servicio agrónomico. **Tu modelo correcto está en esa familia.**

---

## 2. Por qué vertical integration es la decisión correcta

### Lo que YA NO necesitamos hacer (y nos ahorra dinero)

| Cosa | Por qué ya no aplica | Ahorro |
|------|---------------------|--------|
| ATE program (test fab automatizado) | Probamos chips internamente antes de deployment | $20-50k |
| AEC-Q100 / IEC qualification | Solo necesitamos que aguante NUESTRAS condiciones de campo | $100-300k |
| Datasheet para clientes externos | Doc interna basta | $20-50k |
| Sales channel / distributor network | No vendemos | $50-200k/año ongoing |
| Customer support para chips | No tenemos customers de chips | $30-100k/año ongoing |
| Backward compatibility por años | Controlamos cuándo migramos nodos | $20-50k/año ongoing |
| Engineering samples para evaluar | No los necesitamos | $10-30k |
| FAE team (Field Application Engineers) | No los necesitamos | $80-200k/año ongoing |
| Marketing del chip | No existe | $20-50k/año ongoing |
| Pricing strategy para mercado | No aplica | — |

**Ahorro total estimado: $300-500k de NRE eliminado** + $230-650k/año de OpEx ongoing eliminado.

Y estas son las cosas que matan a chip startups (no el silicio en sí, sino el ecosistema alrededor).

### Lo que SÍ tenemos que hacer (y vale la pena)

| Cosa | Por qué sí aplica |
|------|------------------|
| Validar que el chip funciona | Obvio |
| Test interno antes de deploy | Para nuestro propio QA |
| Iteración v1 → v2 → v3 | Para mejorar Zafra |
| Mask set NRE (en su momento) | Sigue siendo cierto en ~año 4-5 |
| Field reliability data | Para saber duración de nodos |
| Documentación interna | Para nuestro equipo |
| Calibración por unidad | Cada chip se calibra contra qPCR/lab |

**Esto es ~30-40% del trabajo de una "chip company" tradicional.** El resto se elimina porque somos usuario, no proveedor.

---

## 3. La economía corregida (sin sales overhead)

### Costo total de Zafra Inc para llegar a 10,000 ha (post-2030)

| Categoría | USD | Notas |
|-----------|-----|-------|
| Mask set NRE (año 4) | $400k | One-time |
| Wafers anuales (año 5+) | $30-50k/año | 30-50k chips/año a $1.50 c/u |
| Chip test interno | $20k/año | Equipo + tiempo, no ATE programa |
| Internal documentation | $10k/año | Tu tiempo |
| Field engineering (qual de chips en condiciones reales) | $30k/año | Validación durante deployment |
| **Total chip-side anual mature** | **~$100k/año** | Para 30-50k chips/año |
| | | |
| **Cost-per-chip mature**: | **$2-3 USD** | Marginal cost producción |

vs. el modelo vendiendo chips:

| | Selling chips | Vertical integration (nosotros) |
|--|---------------|-------------------------------|
| NRE total commercial | $400k + $500k overhead | **$400k solo** |
| Chip cost mature | $5-8 USD (con margen) | **$2-3 USD** (CapEx puro) |
| Time to break-even chip | 4-5 años | **2-3 años** |

**Nuestro modelo es ~$500k USD más eficiente de capital.** Y los chips nos cuestan a nosotros la mitad de lo que costarían si los vendiéramos al mercado.

---

## 4. La trayectoria de costo del chip

### Régimen A: MPW (años 1-3) — barato de entrar, caro por chip

- Compartes wafer con otros diseños
- Pagas por "tu slot" (~$10-25k USD por slot de 9 mm²)
- Recibes 50-100 chips empacados
- **Per-chip: $150-300 USD**
- NRE: ~$15k (el slot mismo)
- Time-to-chip: 4-6 meses

### Régimen B: Full mask set (año 4-5+) — caro de entrar, regalado por chip

- Tú dueño de las máscaras del chip
- Una sola vez pagas el set completo
- Después fabricas wafers casi a costo
- **Per-chip: $0.75-2 USD** (a 180nm con tu die de 8.6 mm²)
- NRE: $250-500k USD una sola vez

### Per wafer con tu chip Nopal-Sense (2935×2935 µm = 8.6 mm²)

```
Wafer GF180 (200mm) = ~31,400 mm² brutos:
- Pérdida de borde + scribe lines: 30%
- Área usable: ~22,000 mm²
- Chips por wafer: 22,000 / 8.6 ≈ 2,500 chips
- Con yield 80%: ~2,000 chips buenos por wafer
- Costo wafer GF180: ~$1,500-3,000

Per-chip: $2,000 / 2,000 = $1 USD por die
+ packaging $1-3 = ~$2-4 USD chip listo
```

**Eso es 75-150x más barato que el régimen MPW.**

### El break-even matemático

```
MPW puro: $250 × N chips
Mask set: $400k + $3 × N chips

Break-even cuando: $250N = $400k + $3N
                   $247N = $400k
                   N = 1,620 chips
```

**Una vez que Zafra necesita ~1,500-2,000 chips lifetime, el mask set es estrictamente más barato.** A nuestro plan: eso ocurre en **año 4-5** (ya con 1,500 nodos desplegados). Decisión que tomamos en 2029, no antes.

### Trayectoria de costo del chip Nopal-Sense

| Año | Etapa | Volumen | Régimen | Costo/chip |
|-----|-------|---------|---------|-----------|
| 2026 | Chipathon | 5-10 | Sponsored | **$0** |
| 2027 | Pilot greenhouse | 10 | Already have | **$0** |
| 2028 | Field expansion piloto | 50-100 | MPW × 1 run | $200-300 |
| 2029 | **Decisión crítica** | 1,500+ | MPW vs mask set | — |
| 2030+ | Escala comercial | 10,000+ | Mask set | **$2-5** |
| 2032+ | LATAM | 100,000+ | Mask set | **$1-2** |

**El escalón es 2029-2030.** Antes: chip caro. Después: chip casi gratis.

---

## 5. La consolidación que justifica vertical integration

El chip NO solo agrega IS — **reemplaza 5 sensores commerciales** que actualmente compramos para cada nodo Zafra.

### BOM por nodo: comparación

```
NODO BAU (commercial sensor stack, hoy):
- 3× humidity capacitive probes:    $15
- EC probe:                          $25
- ADS1115 ADC:                       $7
- Temperature DS18B20:               $5
- VREF externo (LM4040):             $3
- Clock crystal + cap:               $1
- Power management ICs (LDO+gate):   $5
- Discretes / passives extra:        $10
- PCB área (75 cm²):                 $25
- Subtotal sensor stack BOM:         $96

NODO CON CHIP V2 MATURE (post-2030):
- Nopal-Sense chip:                  $3
- Sondas pasivas pines metal:        $40
- Clock crystal:                     $0 (chip generates internal)
- Power management externo:          $2 (chip controls switches)
- Discretes / passives extra:        $5 (much fewer)
- PCB área (25 cm²):                 $8 (smaller PCB)
- Subtotal sensor stack:             $58

SAVINGS por nodo: $96 - $58 = $38

A 10,000 nodos: $380k/año savings JUST from consolidation
A 50,000 nodos: $1.9M/año savings JUST from consolidation
```

**Y el chip se paga solo en 1-2 años post mask-set transition, solo por consolidation**, sin contar el valor de la IS capability.

### Y el chip además reduce complejidad operacional

| Métrica | Stack commercial | Chip-based v2 |
|---------|-----------------|---------------|
| Componentes activos PCB | 12+ | 3-4 |
| Failure modes | 12+ chips × MTBF | 1 chip × MTBF |
| Inventory complexity | 12+ part numbers | 3-4 part numbers |
| Calibration complexity | Cada sensor independiente | Single chip cal |
| Power management | Cada sensor power gate | Programmable switches integrados |
| Clock distribution | XTAL externo + jitter | Single clock fanout from chip |
| IRQ routing | ESP32 GPIO maze | Aggregator clean interface |
| PCB area | ~50-80 cm² | ~15-25 cm² |

**Eso es operacionalmente más robusto, no solo más barato.**

---

## 6. La estrategia dual-pilot

Zafra opera **dos pilotos en paralelo** que NO compiten por recursos:

### Pilot 1 — Field Nextipac (junio 2026)
- **Hardware**: Stack commercial actual (3× humidity cap + EC + ADS1115 + T)
- **Hectáreas**: 100 ha aguacate Hass
- **Goal**: validar operacional + comercial
- **Data**: humidity, EC, T, plant outcomes — sin IS
- **Cost**: ya invertido (BAU)
- **Riesgo que valida**: deployment logistics, instalación, mantenimiento, conectividad LoRa, customer adoption, pricing

### Pilot 2 — Greenhouse research (Q1-Q2 2027)
- **Hardware**: 10 chips chipathon × 7-10 organismos puros
- **Setup**: greenhouse controlado con qPCR ground truth weekly
- **Goal**: validar científico + técnico
- **Data**: IS multi-freq, organism-specific, qPCR-paired
- **Cost**: ~$25k research investment
- **Riesgo que valida**: la apuesta tecnológica core (Stage 1 + Stage 2 evidence)

### Por qué los dos en paralelo (no secuencial)

```
ANTES (sequential approach):                AHORA (parallel):
                                           
1. Build chip                              1. Build chip      ← year 1
2. Validate chip in lab    →               2. Field commercial ← year 1 (parallel)
3. Deploy chip in field                       sensors (operational)
4. Generate revenue                        3. Greenhouse chip ← year 2
                                              validation
                                           4. Migrate to chip ← year 4
                                              when ready
                                              
Time to revenue: 4 años                     Time to revenue: año 1
```

**Los dos pilotos cubren diferentes risk classes simultáneamente.** Si solo tuviéramos uno, dejaríamos 50% de los riesgos sin tocar.

### Migration path 2028+

```
Año 2026-2027: 100% commercial sensors en field
Año 2028:      v1.1 chip en 10-30 nodos (parallel test vs commercial)
Año 2029:      v2 chip en 100-300 nodos (transition mode)
Año 2030+:     v2 chip en todos los nodos nuevos, commercial sensors phased out
```

**Migration es gradual, controlada por Zafra, sin presión de customers externos** (vertical integration permite esto).

---

## 7. El moat real

Aquí va el punto más importante. Zafra NO es "una empresa de chips". El moat es:

```
                  EL MOAT DE ZAFRA-AGTECH
                  
              Chip custom (Nopal-Sense)
                       │
                       ├── Capability única
                       │   (multi-freq IS + integración)
                       │
                       ▼
              Datos únicos de campo
                       │
                       ├── 10k+ nodos × años de IS data
                       │   (NADIE más tiene esto)
                       │
                       ▼
              Modelo ML único (Phytophthora v3+)
                       │
                       ├── Trained on tu data
                       │   (algoritmo es trade secret)
                       │
                       ▼
              Servicio único de protección
                       │
                       ├── 100% retention rate
                       │   (perdiste un cliente = perdiste la cosecha)
                       │
                       ▼
              Network effects
                       │
                       ├── Más nodos = mejor modelo
                       └── Mejor modelo = mejor servicio = más nodos
```

**El chip es solo el primer eslabón.** El verdadero moat es **el dataset que solo Zafra puede generar**, porque:

1. Solo Zafra tiene el chip custom optimizado para soil IS
2. Solo Zafra tiene los nodos deployados a escala
3. Solo Zafra tiene el qPCR ground truth para training
4. Solo Zafra tiene el modelo entrenado

**Apple analogy aplicada**: Apple no es "una empresa de chips M2". Es una empresa de productos donde el chip M2 es UNO de varios moats integrados. Si Apple vendiera M2 al mercado, Qualcomm/AMD lo replicarían en 18 meses. **Lo mantienen exclusivo precisamente porque vertical integration es el moat.**

Tu tesis de "no vendo el chip" es la **decisión correcta** estratégicamente, no una limitación. Es lo que protege todo el negocio.

---

## 8. Revenue model

### Pricing del servicio Zafra-AgTech

| Mercado | Pricing/ha/año | Capability stage requerida |
|---------|----------------|---------------------------|
| Soil health monitoring (organic) | $5-15 | Stage 1 |
| Phytophthora threat detection (avocado) | $80-150 | Stage 1+2 |
| Citrus root rot detection | $60-120 | Stage 1+2 |
| Premium species-specific treatment | $200-500 | Stage 3 |

### Revenue trajectory

| Año | Hectáreas | Stage activo | Revenue/año | Margin |
|-----|-----------|--------------|-------------|--------|
| 2026 | 100 (Nextipac pilot) | Pre-IS (commercial only) | ~$50k | 60% |
| 2027 | 200 | Stage 1 emerging | ~$100k | 65% |
| 2028 | 1,000 | Stage 1+2 transition | ~$500k | 70% |
| 2029 | 3,000 | Stage 1+2 full | ~$2M | 75% |
| 2030 | 5,000 | + Stage 3 emerging | ~$5M | 80% |
| 2031 | 10,000 | Full stack | ~$15M | 85% |
| 2032+ | 25,000+ | LATAM expansion | ~$40M+ | 85%+ |

**Cost-to-revenue ratio mature**: ~10-15% (resto es margen). Eso es la economía Apple-like en AgTech.

---

## 9. Funding strategy

Para llegar al mask set transition ($400k NRE año 4-5), 5 caminos:

### 1. Self-fund desde revenue
- A 1,500 nodos × $200/nodo/año = $300k/año
- Acumulas $400k en 18-24 meses
- **Pros**: zero dilución. **Cons**: lento.

### 2. VC Series A
- AgTech Series A típico: $2-5M
- Mask set es ~10% del raise
- **Pros**: capital + network. **Cons**: dilución 20-30%.

### 3. Strategic partner (Bayer, Corteva, Syngenta)
- $400k es 0.001% de su R&D budget
- A cambio: exclusividad regional, MOU
- **Pros**: capital sin dilución. **Cons**: lock-in.

### 4. CONAHCYT / USDA / BID grants
- USDA SBIR Phase II: hasta $1M para AgTech
- BID Lab: hasta $500k para LATAM innovation
- **Pros**: non-dilutive. **Cons**: papeleo, 6-12 meses.

### 5. Customer pre-pago
- Si tienes 5,000 ha LOI antes de 2029, pides 50% adelantado
- 5,000 ha × $50/ha pre-pago = $250k
- **Pros**: validación de mercado. **Cons**: requires sales maturity.

---

## 10. Comparison: ¿Por qué no usar AD5940 y olvidarse del chipathon?

Argumento legítimo a steelman:

> "AD5940 de Analog Devices ya hace IS multi-frequency. Cuesta $20 a volumen. Lo metes en el nodo y resuelves el problema técnico sin tape-out."

| Aproximación | Chip cost | Diferenciación | NRE | Time-to-market |
|--------------|-----------|----------------|-----|----------------|
| AD5940 + ESP32 | $20 | Baja (genérica) | $0 | 6 meses |
| Nopal-Sense MPW | $250 | Alta | $30k | 18 meses |
| Nopal-Sense mask | $3 | Alta | $400k | 36 meses |

**Si Zafra solo quisiera resolver el problema técnico, AD5940 alcanza.**

Pero AD5940 NO puede:
1. **Optimizarse para suelo** — diseñado para wearables/skin (50-280 mV DC offset que tenemos en suelo no se maneja sin AC coupling externo)
2. **Bajar power a <2 mA** — AD5940 ~1-3 mA active
3. **Consolidar humidity cap + EC + ADC** — son chips separados, BOM más alto
4. **Exportar VREF + clock + power switches** al ESP32
5. **Permitir Stage 3 science** — preset frequencies, no DDS programable wide-range
6. **Generar IP / patentes** sobre arquitectura específica
7. **Sostener moat** — cualquiera puede comprar AD5940

**Si Zafra es solo un negocio de servicio agronómico, AD5940 alcanza.**
**Si Zafra es una empresa de tecnología de hardware con moat técnico real, custom chip lo justifica.**

Esta es la pregunta de negocio que decidimos: vamos por hardware moat. Justifica el tape-out.

---

## 11. Summary executive

| Pregunta | Respuesta |
|----------|-----------|
| ¿Vendemos el chip? | **No.** Vertical integration. |
| ¿Cuánto cuesta el chip mature? | **$2-5/chip** (mask set, post-2030) |
| ¿Cuánto cuesta el nodo completo mature? | **$30-50/nodo** (vs $230 commercial sensor stack today) |
| ¿Cuánto se paga el servicio? | **$80-150/ha/año** Stage 1+2 (avocado threat detection) |
| ¿Cuándo break-even chip vs MPW? | ~1,500 chips lifetime → año 4-5 |
| ¿De dónde sale el $400k NRE? | Revenue + Series A + grants + strategic partner |
| ¿Es necesario chipathon? | **Sí** — chips gratis + paper + mentor + skill |
| ¿Qué pasa si Stage 3 falla? | Stage 1+2 sostienen $30-60M/año MX market |
| ¿Plan de exit? | $1B+ category (Climate Corp/Bayer precedent) |

---

**Last updated**: 2026-05-08 (chipathon kick-off day)
**Next review**: post Project Proposal Review (jun 12 2026)
