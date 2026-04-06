# cc-path — Project-Level Instructions

When used as a project directory (`cd cc-path && claude`), all 18 skills and runtime hooks activate automatically.

## Active Runtime

- **GOLDE Phase Tracker** — UserPromptSubmit hook detects cognitive phase
- **Agent Quality Gate** — PreToolUse:Agent checks "Never Delegate Understanding"
- **Verification Enforcer** — PostToolUse tracks edits, nudges verification at 3+

## 10 Principles (Always Applied)

1. **Read Before Write** — Never modify code you haven't read
2. **Diagnose Before Switching** — Find root cause before changing approach
3. **Minimum Necessary Change** — Only change what was asked
4. **Parallel Independent, Serial Dependent** — Maximize concurrency safely
5. **Verify Before Claiming** — Prove completion with evidence
6. **Cheapest First** — Exhaust low-cost sources first
7. **Fail Closed** — When uncertain, fail safe
8. **Never Delegate Understanding** — Synthesize, then delegate with specs
9. **Explicit Over Clever** — 3 lines > premature abstraction
10. **Cache Economics Drive Architecture** — Minimize repetition costs

## Skill Auto-Routing

| Context | Primary Skill | Secondary |
|---------|--------------|-----------|
| Code | principles | architecture |
| Debug | problem-solve | verify |
| Plan | strategic-plan | research |
| Docs | document-craft | prompt-craft |
| Agent | agent-mastery | token-zero |
| Research | research | context-engine |
| Multi-agent | multi-agent | agent-automation |
| Efficiency | token-zero | context-engine |

## Available Skills (18)

All in `.claude/skills/anthropic-*/SKILL.md`. Invoke via `/anthropic-*` or let auto-detection handle it.
