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

## Skills (8)

`/research` · `/build` · `/code-review` · `/plan` · `/deploy` · `/debug` · `/critique` · `/decision`

## Agents (12)

| Tier | Agent | Model | Access | Role |
|------|-------|-------|--------|------|
| Orchestration | `coordinator` | opus | read-only | Task decomposition + synthesis |
| | `critic` | opus | read-only | Devil's advocate, challenge assumptions |
| Strategic | `analyst` | sonnet | read-only | Requirements + acceptance criteria |
| | `planner` | opus | read-only | Decompose into parallel subtasks |
| Analysis | `researcher` | opus | read-only | Evidence gathering, FACT/INTERP/ASSUMPTION |
| | `architect` | opus | read-only | System design + trade-off analysis |
| Implementation | `builder` | sonnet | read-write | Production code, minimal complexity |
| | `reviewer` | opus | read-only | Code review, never modifies files |
| | `tester` | sonnet | read-write | Tests + edge cases, independent from builder |
| | `writer` | sonnet | read-write | Docs, READMEs, "brilliant friend" voice |
| Safety | `security` | opus | read-only | Threat modeling, OWASP, secret exposure |
| | `red-teamer` | opus | read-write | Adversarial attacks, try to break things |

Select minimum agents per task. Bug fix = 2. Feature = 5. Security audit = 7.

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
