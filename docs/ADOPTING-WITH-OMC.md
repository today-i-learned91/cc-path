# Adopting cc-path with oh-my-claudecode (OMC)

cc-path is a **governance layer**; OMC is an **orchestration layer**. They cover
different dimensions: what the system *must never do* (cc-path) vs *how it
coordinates complex work* (OMC).

## What Each Layer Provides

| Layer | Provided by | Enforcement |
|-------|-------------|-------------|
| Safety hooks (deploy-guard, circuit-breaker, input-sanitizer, cognitive-protection, decision-audit) | cc-path | 100% — cannot be talked past |
| Principled guidance (thinking-framework, cognitive-protection rules) | cc-path | ~80% — shapes behavior |
| Multi-agent orchestration (Team, Autopilot, Ralph) | OMC | Coordinated execution |
| Workflow skills + HUD | OMC | On-demand invocation |

**cc-path hooks fire on every tool call, including calls made by OMC agents.**
When Autopilot's executor runs `Bash`, deploy-guard still executes. Governance
is not bypassed by orchestration. This is Anthropic's guidance vs governance
distinction in practice: OMC operates at the guidance layer; cc-path's hooks
operate at the governance layer beneath it.

## Setup

```bash
# 1. Install OMC normally (creates ~/.claude/ with OMC hooks + skills)

# 2. Copy cc-path's hooks and rules into your project
git clone https://github.com/today-i-learned91/cc-path.git
cp -r cc-path/harness/.claude/hooks your-project/.claude/hooks
cp -r cc-path/harness/.claude/rules your-project/.claude/rules
```

**Merge settings.json** — hooks concatenate, not override. Append cc-path's
entries into OMC's existing arrays:

```json
"PreToolUse": [
  // ... OMC entries ...
  { "matcher": "Bash",
    "hooks": [{ "type": "command", "command": ".claude/hooks/deploy-guard.sh", "timeout": 5 }] },
  { "matcher": "Bash|Edit|Write|NotebookEdit|WebFetch|mcp__*",
    "hooks": [{ "type": "command", "command": ".claude/hooks/circuit-breaker-gate.sh", "timeout": 3 }] },
  { "matcher": "Bash|Edit|Write|NotebookEdit",
    "hooks": [{ "type": "command", "command": ".claude/hooks/cognitive-protection.sh", "timeout": 3 }] },
  { "matcher": "Bash|WebFetch|mcp__*",
    "hooks": [{ "type": "command", "command": ".claude/hooks/input-sanitizer.sh", "timeout": 3 }] }
],
"PostToolUse": [
  // ... OMC entries ...
  { "matcher": "Bash|Edit|Write|NotebookEdit|WebFetch|Agent",
    "hooks": [{ "type": "command", "command": ".claude/hooks/decision-audit.sh", "timeout": 3 }] }
],
"PostToolUseFailure": [
  { "hooks": [{ "type": "command", "command": ".claude/hooks/circuit-breaker.sh", "timeout": 3 }] }
]
```

The full reference is in `harness/.claude/settings.json`.

## How They Work Together

- **Autopilot / Team**: sub-agent tool calls pass through cc-path hooks. An executor
  attempting `--force` deploy is blocked before the model acts on it.
- **Ralph / Ultrawork**: long autonomous sessions. decision-audit logs every
  significant action to `/tmp/claude-audit-{session}/decisions.jsonl`.
- **Circuit breaker**: tracks failures across all parallel OMC workers — five
  consecutive failures trips the gate regardless of which agent caused them.

## Principle

> "CLAUDE.md = guidance (~80%), Hooks = governance (100%)" — cc-path Safety Standards

OMC agents are powerful, which makes governance more important, not less.
OMC coordinates intelligent work; cc-path ensures that work stays within
pre-committed safety boundaries no matter what any agent decides.
