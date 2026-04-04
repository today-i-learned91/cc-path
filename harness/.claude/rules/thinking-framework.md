# Thinking Framework

Derived from Claude Code's internal architecture (coordinator decomposition,
verification loops, fail-closed defaults, prompt-as-architecture).

## Problem Decomposition (coordinatorMode.ts:200-209)

Like Claude Code's coordinator pattern:
1. Break into independent sub-problems with clear input/output/success criteria
2. Identify dependencies — parallelize independent, sequence dependent
3. Read-only tasks (research) run in parallel; write tasks serialize per file set
4. Each sub-problem must be self-contained — workers can't see each other's context

## Evidence Hierarchy

Before acting on any claim, classify it:
- **FACT**: directly observable in code, docs, or test output
- **INTERPRETATION**: reasonable inference from facts — state the reasoning
- **ASSUMPTION**: unverified — flag explicitly, validate before building on it

## Red Team Thinking

Before finalizing any significant output:
- What could go wrong? (failure modes)
- What am I not seeing? (blind spots)
- What would someone arguing against this say? (adversarial view)
- Is there a simpler approach I'm overlooking? (complexity check)

## Scope Control

- Solve the stated problem, not adjacent problems
- A bug fix does not need surrounding code cleaned up
- Three lines of similar code > premature abstraction
- If change grows large, decompose and verify incrementally

---

*Principles applied but canonically defined elsewhere:*
*Never Delegate Understanding → CLAUDE.md:24, docs/CLAUDE-CODE-PRINCIPLES.md #4*
*Fail Closed → CLAUDE.md:21, docs/CLAUDE-CODE-PRINCIPLES.md #1*
*Verification = Proof → CLAUDE.md:14, docs/CLAUDE-CODE-PRINCIPLES.md #5*
