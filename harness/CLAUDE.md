# Project Hub

Multi-project workspace. Sub-projects inherit this configuration
via Claude Code's CWD-to-root traversal (later = higher priority).

## Cognitive Cycle

Every task follows GOLDE (Goal→Output→Limits→Data→Evaluation) × 6-phase cycle.

1. **ORIENT** — What is the actual problem? Read existing code/docs first.
2. **ANALYZE** — Gather evidence. Classify as FACT / INTERPRETATION / ASSUMPTION.
3. **PLAN** — Decompose into phases. Parallelize independent work.
4. **EXECUTE** — Small verified steps. Commit atomically. No speculative abstractions.
5. **VERIFY** — Prove, don't confirm. Run tests with feature enabled. Be skeptical.
6. **LEARN** — Update memory/docs only for non-obvious insights.

Depth: Quick (1-3 sections) · Normal (all) · Deep (+ alternatives + risks + sources).

## Design Principles

- **Fail Closed, Default Safe** — restrictive defaults, opt-in only
- **Prompt Is Architecture** — CLAUDE.md layers encode system behavior
- **Progressive Compression** — 3-layer context: always / conditional / on-demand
- **Never Delegate Understanding** — prove comprehension with file:line before delegating
- **Data-Driven Circuit Breakers** — thresholds from measurement, not intuition
- **Feature Flags as Dead Code Elimination** — unused config must not load
- **Explicit Over Clever** — no implicit dependencies, no magic

## Sub-Projects

- Naming: `YYYY-MM-DD-name/` or `name/`
- Each MUST have `CLAUDE.md`: purpose, tech stack, constraints, active task
- Sub-project CLAUDE.md overrides parent (highest priority)

## Skills (7)

`/research` · `/build` · `/code-review` · `/plan` · `/critique` · `/decision` · `/deploy`

## Agents (3)

`researcher` (opus, read-only) · `builder` (sonnet) · `reviewer` (opus, read-only)

## Safety Standards

- **Secrets**: `.env` files only, never hardcoded. `.env.example` for templates
- **Automation**: dry-run mode mandatory before live. Lockfile for concurrent prevention
- **External APIs**: timeout + retry + circuit breaker (3 consecutive failures → disable)
- **Deployment**: `deploy-guard.sh` blocks `--prod`/`--force` via PreToolUse hook
- **Principle**: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)"

## Core Rules

- English for all harness files
- Read before write; verify before completion
- Minimal changes; no speculative abstractions
- Reference docs in `docs/` loaded on demand
