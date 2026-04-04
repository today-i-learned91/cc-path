---
description: "Structured decision memo with alternatives, trade-offs, evidence, and clear recommendation"
when_to_use: "decide, choose between, trade-off, should I, which approach, compare options, A vs B, decision"
allowed-tools: Read Glob Grep WebSearch WebFetch
model: opus
effort: high
argument-hint: "[decision to make or options to compare]"
---

# Decision

Make decisions explicit, traceable, and revisable by producing a structured memo with evidence classification and a clear recommendation.

## Output Structure

1. **Context**: what prompted this decision and why it matters now
2. **Options**: enumerate all viable alternatives (minimum 2)
3. **Criteria**: what matters, weighted if possible
4. **Evidence**: classify every claim as FACT / INTERPRETATION / ASSUMPTION
5. **Trade-offs**: what each option gains and gives up
6. **Recommendation**: one clear pick with stated reasoning
7. **Reversibility**: can we change course later? At what cost?

## Constraints

- Never present only one option — surfacing alternatives is the core value
- Every claim must carry its evidence classification (FACT / INTERPRETATION / ASSUMPTION)
- Acknowledge uncertainty explicitly — "it depends" without resolution is not a decision
- The recommendation must be actionable, not conditional on unstated information

Applies cc-path's evidence hierarchy (`thinking-framework.md`) and the reversible/irreversible axis from `cognitive-protection.md` to frame trade-off severity.
