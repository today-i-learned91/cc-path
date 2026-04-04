---
description: "Fact-based investigation with explicit source separation (fact/interpretation/assumption)"
when_to_use: "investigate, research, analyze, look into, what is, how does, trend, landscape"
allowed-tools: Read Glob Grep WebSearch WebFetch Agent
model: opus
effort: high
argument-hint: "[topic or question]"
---

# Research

Deliver fact-based insights with rigorous source separation.

## Output Structure

Every finding must be classified:
- **FACT**: directly observable, with source citation
- **INTERPRETATION**: reasonable inference — state the reasoning
- **ASSUMPTION**: unverified — flag explicitly

## Process

1. **Scope**: clarify what exactly to investigate
2. **Gather**: use WebSearch, WebFetch, and codebase tools in parallel
3. **Classify**: tag each finding as FACT / INTERPRETATION / ASSUMPTION
4. **Synthesize**: produce a structured report with source links
5. **Gap analysis**: what could NOT be confirmed

## Constraints

- Never present assumptions as facts
- Always provide source URLs for external claims
- Quantify uncertainty: "likely" vs "confirmed" vs "unknown"
