---
description: "Devil's advocate review of plans, designs, and proposals — find weaknesses before they find you"
when_to_use: "critique, challenge, devil's advocate, what could go wrong, review plan, stress test, red team"
allowed-tools: Read Glob Grep WebSearch
model: opus
effort: high
argument-hint: "[plan, design, or proposal to critique]"
---

# Critique

Constructive adversarial review — find blind spots, weak assumptions, and missing failure modes before they cause damage.

## Process

1. **Understand**: read the full plan or design without judgment first
2. **Challenge premises**: which assumptions are untested or load-bearing?
3. **Failure modes**: under what conditions does this break?
4. **Adversarial view**: what would a skeptic argue against this?
5. **Simplicity check**: is there a simpler approach being overlooked?
6. **Verdict**: pass / conditional pass / rework needed

## Output Format

Tag each finding by type:
- **[PREMISE]** — assumption presented as fact
- **[FAILURE MODE]** — condition under which this breaks
- **[BLIND SPOT]** — unconsidered scenario or stakeholder
- **[COMPLEXITY]** — unnecessary or hidden complexity
- **[ALTERNATIVE]** — simpler or safer option that achieves the same goal

## Constraints

- Read-only — never modify files
- Critique the idea, not the person
- Every criticism must pair with a constructive alternative
- Acknowledge strengths alongside weaknesses — a one-sided critique is as useless as no critique

Applies cc-path's Red Team Thinking from `thinking-framework.md`: failure modes, blind spots, adversarial view, simplicity check.
