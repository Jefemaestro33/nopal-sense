# Architecture Decision Records (public)

Technical decisions taken during chipathon execution. **Public** — keep content technical-rationale focused. Strategic/business decisions go to Zafra-Agtech repo privado.

## What is an ADR

An Architecture Decision Record captures **why** a technical decision was made, not just **what** was decided. Future-you (or future collaborators, mentors, paper reviewers) reads it to understand the reasoning behind a choice.

## Naming convention

`ADR-NNN-topic.md`

Examples:
- `ADR-001-frequency-choice-10k-30k-100k.md` (resolves OQ-006)
- `ADR-002-dc-offset-cancellation-firmware-autozero.md` (resolves OQ-007)
- `ADR-003-tia-topology-shunt-feedback.md` (resolves OQ-001)
- `ADR-004-padring-workshop-slot-88pin.md`
- `ADR-005-process-variant-MCUD-vs-MCU.md`

## Template

```markdown
# ADR-NNN: [Decision title]

**Status**: Proposed | Accepted | Superseded by ADR-XXX | Deprecated
**Date**: YYYY-MM-DD
**Deciders**: [Darell, Mentor X, ...]
**Resolves**: [OQ-NNN if applicable]

## Context

What is the problem? What constraints exist? What alternatives were on the table?

## Decision

What was decided.

## Rationale

Why this option vs alternatives. Quantitative reasoning where possible.

## Consequences

**Positive**:
- ...

**Negative**:
- ...

**Neutral**:
- ...

## References

- Related meeting: `docs/_meeting_notes/YYYY-MM-DD_topic.md`
- Related Open Question in spec: OQ-NNN
- Reference papers: [DOI / URL]
- Mentor input: [name + date]
```

## Examples of "what's a public technical ADR"

✅ Frequency choice for IS sweep (OQ-006)
✅ TIA topology selection (OQ-001)
✅ ADC sharing strategy (IS + sensors time-multiplexed)
✅ Process variant selection (MCUD vs MCU)
✅ Solo vs team (technical scope implications)
✅ Modular spine priority labeling P1/P2/P3

## Examples of "what's NOT a public ADR" (goes to Zafra private)

❌ Whether to accept Jatin as collaborator (relational/business)
❌ How to handle UP mentor pushback (relationship management)
❌ Customer pricing strategy (business)
❌ Funding path selection (business)
❌ Phytophthora algorithm v3+ implementation (trade secret)
