---
description: "Systematic debugging with 4-phase root cause analysis: investigate, analyze, hypothesize, implement"
when_to_use: "debug, fix bug, why is this broken, error, crash, investigate, root cause, not working"
allowed-tools: Read Glob Grep Bash Agent
model: opus
effort: high
argument-hint: "[error description or symptoms]"
---

# Debug

Find the root cause before writing a single line of fix. Symptoms mislead; causes don't.

## Process

1. **INVESTIGATE**: reproduce the issue reliably; gather logs, stack traces, `git blame`, recent commits
2. **ANALYZE**: classify each piece of evidence as FACT / INTERPRETATION / ASSUMPTION; identify what changed
3. **HYPOTHESIZE**: generate 2-3 competing hypotheses; design a discriminating test for each
4. **IMPLEMENT**: fix the root cause (not the symptom); verify the fix; check for regressions

## Iron Law

No fix without root cause identification. A fix that cannot be explained cannot be trusted.

## Constraints

- Never retry an identical action more than once — diagnose before retrying
- Read before write — understand the code path before modifying it
- Each hypothesis must be testable; discard hypotheses that cannot be falsified
- After fixing, confirm: does the original reproduction case now pass?
- After fixing, check: does anything adjacent break? (regression sweep)
- Reference: thinking-framework.md Evidence Hierarchy and Problem Decomposition
