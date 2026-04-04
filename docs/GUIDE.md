# Building Your Harness: A Step-by-Step Guide

How to build a principled Claude Code workspace from scratch. This guide
explains HOW and WHY -- because understanding the principles matters more than
copying files. The `harness/` directory has the reference implementation;
this guide teaches you to build your own.

---

## Prerequisites

- Claude Code installed and working in a project directory
- Basic understanding of Claude Code's CLAUDE.md system

---

## Phase 1: Foundation (CLAUDE.md)

The foundation layer loads on every request. Every token here costs you on
every interaction, so be precise.

### Step 1: Create Your Root CLAUDE.md

**What goes here**: cognitive cycle, design principles, safety standards.

**Why**: This is your "constitution" -- the declarative norms Claude uses for
self-guidance. Constitutional AI trains models to critique their own outputs
against principles, not to follow a rule list. Your CLAUDE.md works the same
way. Amanda Askell's insight: character (how to think) outperforms rules
(what to do). Source: arXiv:2212.08073, *Claude's Character* (2024).

**Budget**: 60-80 lines, under 4KB.

```markdown
# Project Name

Brief purpose (1-2 sentences).

## Cognitive Cycle

1. **ORIENT** -- Read existing code/docs first.
2. **ANALYZE** -- Classify evidence as FACT / INTERPRETATION / ASSUMPTION.
3. **PLAN** -- Decompose into phases. Parallelize independent work.
4. **EXECUTE** -- Small verified steps. No speculative abstractions.
5. **VERIFY** -- Prove, don't confirm. Run tests with feature enabled.
6. **LEARN** -- Update docs only for non-obvious insights.

## Design Principles

- **Fail Closed, Default Safe** -- restrictive defaults, opt-in only
- **Prompt Is Architecture** -- CLAUDE.md layers encode system behavior
- **Progressive Compression** -- 3-layer context: always / conditional / on-demand
- **Never Delegate Understanding** -- prove comprehension with file:line
- **Explicit Over Clever** -- no implicit dependencies, no magic

## Safety Standards

- **Secrets**: `.env` files only, never hardcoded
- **Deployment**: `deploy-guard.sh` blocks `--prod`/`--force` via hook
- **Principle**: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)"

## Core Rules

- Read before write; verify before completion
- Minimal changes; no speculative abstractions
```

Each section traces to a source. The Cognitive Cycle encodes "build to
understand" (Dario Amodei, *Machines of Loving Grace*). "Fail Closed" comes
from `Tool.ts:748` where `isConcurrencySafe` defaults to false. "Read before
write" derives from Chris Olah's interpretability methodology -- understand
the system before modifying it (`constants/prompts.ts:230`).

### Step 2: Create .claude/CLAUDE.md

**What goes here**: development conventions, quality gates, testing strategy.

**Why**: Separates "what this project IS" (root) from "how we work" (.claude/).
Sub-projects can override conventions while inheriting the constitution.
Claude Code's loading order makes this explicit -- later files override earlier.
Source: `getMemoryFiles` in `claudemd.ts`.

**Budget**: 60 lines, under 3KB.

```markdown
# Development Conventions

## Quality Gates

- **Pre-action**: Do I understand the problem? Have I read the code?
- **Execution**: Am I making the minimal correct change?
- **Post-action**: Does this work? Can I prove it?
- **Failure recovery**: What's the root cause before retrying?

## Code Quality

- No unused imports, variables, or dead code
- Three similar lines > premature abstraction
- Comments only where logic is non-obvious

## Context Architecture

Loading order (source: getMemoryFiles in claudemd.ts):
1. Managed -> User -> Project (root->CWD) -> Local -> AutoMem
2. `.claude/rules/*.md` without `paths` -> always loaded
3. `.claude/rules/*.md` with `paths` -> loaded on matching file access
4. `.claude/skills/*.md` -> frontmatter only; body on invocation
```

Quality Gates map to Claude Code's PreToolUse -> PostToolUse -> Failure
hook chain. They are a mental model, not a checklist.

---

## Phase 2: Conditional Intelligence (Rules)

Rules in `.claude/rules/` can load conditionally or unconditionally.
This is where "Progressive Compression" pays off -- context that loads
only when relevant costs zero tokens otherwise.

### Step 3: Thinking Framework

Create `.claude/rules/thinking-framework.md` -- Claude's reasoning protocol.

Key sections to include:

- **Problem Decomposition**: Break into sub-problems, parallelize independent
  tasks, serialize writes. Source: `coordinatorMode.ts:200-209`.
- **Evidence Hierarchy**: Classify claims as FACT (observable, cite source),
  INTERPRETATION (inference, state reasoning), ASSUMPTION (unverified, flag it).
- **Red Team Thinking**: Before finalizing output, ask: what could go wrong?
  What am I not seeing? Is there a simpler approach?
- **Scope Control**: Solve the stated problem, not adjacent ones. Three similar
  lines of code is better than a premature abstraction.

This defines thinking character, not behavioral rules. Amanda Askell's insight:
character generalizes to novel situations; rules are brittle at the boundary.
See `harness/.claude/rules/thinking-framework.md` for the full implementation.

### Step 4: Cognitive Protection

Create `.claude/rules/cognitive-protection.md` -- the decision matrix.

The core is a 2x2 matrix on two axes: Reversible/Irreversible and
Objective/Subjective.

```
|            | Reversible    | Irreversible  |
|------------|---------------|---------------|
| Objective  | Auto-pass     | Soft confirm  |
| Subjective | Soft confirm  | Hard confirm  |
```

Add escalation triggers that override the matrix: auth, payments, PII,
batch operations (10+ files). These always require hard confirm.

**Why a matrix, not a list**: Lists cannot cover every case. A 2x2 framework
generalizes to novel situations. This mirrors RSP's if-then commitment
structure -- pre-committed responses, not case-by-case judgment.
Source: *Responsible Scaling Policy v1-v3*.

### Step 5: Conditional Loading

Add `paths:` frontmatter to rules that are not needed every session:

```yaml
---
paths:
  - "**/*.sql"
  - "**/migrations/**"
---
```

This rule loads only when Claude accesses matching files. A workspace with
10 rules where 6 use `paths:` saves thousands of tokens per session versus
loading everything unconditionally. Source: `claudemd.ts` rule loading logic.

---

## Phase 3: Governance (Hooks)

Everything above is guidance -- Claude follows it ~80% of the time, but under
token pressure, guidance can be skipped. Hooks cannot. They execute outside
the model's control via `settings.json`.

**The key insight**: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)."

### Step 6: Deploy Guard

Create `.claude/hooks/deploy-guard.sh` -- blocks dangerous production commands.

The script reads `$CLAUDE_TOOL_INPUT`, extracts the command via `jq`, and
pattern-matches against dangerous operations (`--force`, `npm publish`,
`firebase deploy`, `vercel --prod`). On match: write a JSON denial to stderr
and exit 2. Otherwise: exit 0.

```bash
#!/bin/bash
# Exit 0 = allow, Exit 2 = block
COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

for pattern in '--force' 'git push.*-f ' 'npm publish' 'firebase deploy'; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Production deployment blocked. Run manually after confirmation."}}' >&2
    exit 2
  fi
done
exit 0
```

Make it executable: `chmod +x .claude/hooks/deploy-guard.sh`

**Why hooks over CLAUDE.md for this**: A CLAUDE.md instruction "never force-push"
works ~80% of the time. A PreToolUse hook works 100%. For safety-critical
operations, 80% is not acceptable.

### Step 7: Circuit Breaker

Prevents runaway failure loops using three scripts:

| Script | Hook Event | Purpose |
|--------|-----------|---------|
| `circuit-breaker.sh` | PostToolUseFailure | Increment counter, warn at 3, alert at 5 |
| `circuit-breaker-gate.sh` | PreToolUse | Block tool calls when counter >= 5 |
| `circuit-breaker-reset.sh` | PostToolUse | Reset counter to 0 on any success |

The warn-then-block pattern comes from Claude Code's own `autoCompact.ts:67-70`
where `MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3` triggers a mode change. We
warn at 3 (inject context urging a new approach) and block at 5 (deny the call).

State is isolated per session via `$CLAUDE_SESSION_ID` in the temp file path.
See `harness/.claude/hooks/circuit-breaker*.sh` for the complete implementation.

### Step 8: Wire Hooks in settings.json

Create `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": ".claude/hooks/deploy-guard.sh", "timeout": 5}]
      },
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [{"type": "command", "command": ".claude/hooks/circuit-breaker-gate.sh", "timeout": 3}]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [{"type": "command", "command": ".claude/hooks/circuit-breaker-reset.sh", "timeout": 3}]
      }
    ],
    "PostToolUseFailure": [
      {
        "hooks": [{"type": "command", "command": ".claude/hooks/circuit-breaker.sh", "timeout": 3}]
      }
    ]
  }
}
```

**Scoping matters**: Deploy guard matches only `Bash` (only Bash runs shell
commands). Circuit breaker gate matches `Bash|Edit|Write` -- mutation tools
only. Never match `Read`/`Glob`/`Grep` -- blocking reads during a failure
spiral prevents recovery. PostToolUse reset has no matcher -- any success
resets the counter.

---

## Phase 4: On-Demand Knowledge (Skills)

Skills use three-level progressive disclosure: only frontmatter loads into
context (~70 tokens per skill); the body loads on invocation.

### Step 9: Create Your First Skill

Create `.claude/skills/research.md`:

```yaml
---
description: "Fact-based investigation with source separation"
when_to_use: "investigate, research, analyze, look into, how does"
allowed-tools: Read Glob Grep WebSearch WebFetch Agent
model: opus
effort: high
---
```

The body contains the full research protocol: output structure (FACT /
INTERPRETATION / ASSUMPTION classification), process steps, and constraints.

Key frontmatter fields:
- `allowed-tools`: Constrains tool access. Research should not have Write --
  separation of creation from judgment (Constitutional AI critique-revision).
- `model`/`effort`: Right-size the model to the task.

Without skills, this protocol would live in CLAUDE.md (~300 always-loaded
tokens). With skills, you pay ~70 idle tokens and load the body only when
invoked -- a 4x reduction per skill.

---

## Phase 5: Verification

### Step 10: Test Your Harness

**Hooks**: Ask Claude to run `git push --force origin main`. Deploy guard
should block it. You see the denial message, not a push attempt.

**Rules**: Ask Claude "What rules are currently loaded?" Your unconditional
rules should appear. Access a file matching a `paths:`-scoped rule and ask
again -- it should now appear.

**Skills**: Invoke `/research [topic]`. Claude should follow the skill's
output structure and classify findings using the Evidence Hierarchy.

**Circuit breaker** (manual test):

```bash
echo "5" > /tmp/claude-circuit-breaker-test
CLAUDE_SESSION_ID=test .claude/hooks/circuit-breaker-gate.sh
echo $?  # Should print 2 (blocked)
rm /tmp/claude-circuit-breaker-test
```

---

## Architecture Diagram

```
your-project/
+-- CLAUDE.md                       Layer 1: Always      ~1.5K tokens
+-- .claude/
    +-- CLAUDE.md                   Layer 1b: Always     ~1K tokens
    +-- rules/                      Layer 2: Conditional  0 until triggered
    |   +-- thinking-framework.md
    |   +-- cognitive-protection.md
    +-- skills/                     Layer 3: On-demand   ~70 tokens each
    |   +-- research.md
    +-- hooks/                      Layer G: Governance   0 context tokens
    |   +-- deploy-guard.sh
    |   +-- circuit-breaker.sh
    |   +-- circuit-breaker-gate.sh
    |   +-- circuit-breaker-reset.sh
    +-- settings.json

Idle total: ~2.5-3K tokens (vs ~4K for a monolithic 500-line CLAUDE.md)
```

---

## Common Mistakes

**1. Loading everything unconditionally.** Every token in always-loaded files
costs you on every request. Use `paths:` frontmatter and skills to defer.

**2. Rules without hooks (aspirational safety).** "Never force-push" in
CLAUDE.md works ~80% of the time. For safety-critical operations, the
remaining 20% is where incidents happen. Add the hook.

**3. Hooks without rules (enforcement without explanation).** Claude gets
blocked but doesn't understand why, leading to confused workarounds.
Guidance explains intent; hooks enforce it. You need both.

**4. Duplicating principles across files.** The Evidence Hierarchy defined
in CLAUDE.md, again in thinking-framework.md, and again in a skill. When
you update one, the others drift. Define once, reference by path.

**5. Oversized CLAUDE.md.** Audit quarterly. If a section is only sometimes
relevant, make it a conditional rule. If only for specific workflows, a skill.

**6. No circuit breaker.** Without one, Claude retries failing approaches
indefinitely. The three-script lifecycle is simple and prevents the most
common failure mode in extended sessions.

---

## Next Steps

1. **Add skills** as workflows stabilize: `/build`, `/code-review`, `/deploy`.
2. **Add conditional rules** for tech-stack-specific guidance (`*.sql`, `*.tsx`).
3. **Prune quarterly.** Rules untriggered for 90 days are archival candidates.
4. **Read the philosophy.** `docs/ANTHROPIC-PHILOSOPHY.md` maps Anthropic's
   published thinking to harness mechanisms. The *why* makes you better at
   adapting the harness to your needs.

---

## Sources

- Bai, Y. et al. (2022). *Constitutional AI: Harmlessness from AI Feedback*. arXiv:2212.08073
- Amodei, D. (2024). *Machines of Loving Grace*. darioamodei.com
- Askell, A. (2024). *Claude's Character*. anthropic.com/research/claude-character
- Anthropic. (2023-2025). *Responsible Scaling Policy v1-v3*. anthropic.com/research/responsible-scaling-policy
- Olah, C. et al. (2020). *Zoom In: An Introduction to Circuits*. Distill.
- Claude Code source: `Tool.ts:748`, `coordinatorMode.ts:200-268`, `claudemd.ts`, `autoCompact.ts:67-70`
