# Adopting cc-path with Superpowers

Superpowers and cc-path address different questions. Superpowers asks *what to
build and how to build it well* (methodology). cc-path asks *what the system must
never be allowed to do* (safety boundaries). They do not overlap.

## What Each Layer Provides

| Layer | Provided by | Focus |
|-------|-------------|-------|
| Safety governance | cc-path | deploy-guard, circuit-breaker, input-sanitizer, cognitive-protection hook, decision-audit |
| Principled guidance | cc-path | Evidence hierarchy, thinking framework, cognitive protection matrix |
| Development methodology | Superpowers | TDD workflows, brainstorming, structured code review |

Guidance (~80% reliable): Superpowers' methodology + cc-path's CLAUDE.md principles.
Governance (100% enforced): cc-path's hooks — these fire regardless of what any
prompt says. Superpowers makes Claude a better developer; cc-path ensures that
developer cannot be directed toward unsafe actions no matter how a session evolves.

## Setup

```bash
# 1. Install Superpowers plugin per its installation guide

# 2. Copy cc-path's governance layer (does not touch Superpowers' files)
git clone https://github.com/today-i-learned91/cc-path.git
cp -r cc-path/harness/.claude/hooks your-project/.claude/hooks
cp -r cc-path/harness/.claude/rules your-project/.claude/rules

# 3. Add hooks to settings.json
# If Superpowers created one, merge. If not:
cp cc-path/harness/.claude/settings.json your-project/.claude/settings.json

# 4. Optionally overlay cc-path's root principles
cat cc-path/harness/CLAUDE.md >> your-project/CLAUDE.md
```

When merging `settings.json`, append cc-path's `PreToolUse`, `PostToolUse`, and
`PostToolUseFailure` entries into Superpowers' existing arrays. See
`harness/.claude/settings.json` for the full entry list. Hooks concatenate —
deploy-guard should appear early in PreToolUse so it blocks before other hooks run.

## How They Complement Each Other

**TDD workflow**: Superpowers drives test-first implementation. cognitive-protection
adds friction before irreversible writes — deleting files or changing 10+ files at
once triggers a soft or hard confirm. Superpowers decides *what* to build;
cc-path ensures irreversible steps get deliberate approval.

**Brainstorming**: Superpowers explores options freely. thinking-framework structures
evidence classification (FACT / INTERPRETATION / ASSUMPTION) when options are
evaluated — good ideas stay, unverified assumptions get flagged before implementation.

**Code review**: Superpowers identifies quality issues. decision-audit logs the
session's tool call sequence to JSONL, giving reviewers a traceable record of
what changed and why — not just the diff but the action sequence.

## Principle

> "Constitutional AI's core insight: a model trained to follow principles outperforms
> one trained to follow rules. Rules are brittle at the boundary; values generalize."
> — ANTHROPIC-PHILOSOPHY.md, Section 1.2

Superpowers internalizes good methodology as guidance. cc-path's hooks are the
pre-committed constraints written *before* any session starts — before the pressure
to bypass them ever arrives. Both halves are necessary: principled guidance shapes
most behavior; hard boundaries handle the cases where guidance alone is not enough.
