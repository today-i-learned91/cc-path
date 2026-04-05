# Cookbook -- Common Recipes

Quick patterns for common harness tasks. See [GUIDE.md](GUIDE.md) for full rationale.

---

## Setup Recipes

### Minimal Setup

**When to use**: Deploy protection only. Lowest friction entry point.

1. Copy `harness/CLAUDE.md` to your project root.
2. Copy `hooks/deploy-guard.sh` to `.claude/hooks/`. `chmod +x .claude/hooks/deploy-guard.sh`
3. Create `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash",
       "hooks": [{"type": "command", "command": ".claude/hooks/deploy-guard.sh", "timeout": 5}]}
    ]
  }
}
```

**Result**: Claude cannot force-push or deploy to production without manual confirmation.

---

### Standard Setup

**When to use**: New project. Adds reasoning rules and failure loop prevention.

1. Complete Minimal Setup.
2. Copy `rules/thinking-framework.md` and `rules/cognitive-protection.md` to `.claude/rules/`.
3. Copy `hooks/circuit-breaker*.sh` to `.claude/hooks/`. Make all executable.
4. Wire: `circuit-breaker-gate.sh` on `Bash|Edit|Write` (PreToolUse),
   `circuit-breaker-reset.sh` (PostToolUse), `circuit-breaker.sh` (PostToolUseFailure).

See [GUIDE.md -- Phase 3](GUIDE.md) for the complete settings.json block.

---

### Strict Setup

**When to use**: Teams, long autonomous sessions, projects touching sensitive data.

1. Complete Standard Setup.
2. Copy `hooks/cognitive-protection.sh`, `hooks/input-sanitizer.sh`,
   `hooks/decision-audit.sh` to `.claude/hooks/`. Make all executable.
3. Add to PreToolUse: `cognitive-protection.sh` on `Bash|Edit|Write|NotebookEdit`,
   `input-sanitizer.sh` on `Bash|WebFetch|mcp__*`.
4. Add to PostToolUse: `decision-audit.sh` on `Bash|Edit|Write|NotebookEdit|WebFetch|Agent`.

**Result**: Full governance. Every mutation logged, adversarial inputs flagged,
irreversible actions require explicit confirmation.

---

## Customization Recipes

### Adding a Custom Hook

**When to use**: Project-specific enforcement (e.g., block writes to a protected directory).

1. Create `.claude/hooks/your-hook.sh`:

```bash
#!/bin/bash
INPUT=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // .command // empty' 2>/dev/null)
[ -z "$INPUT" ] && exit 0
if echo "$INPUT" | grep -qE 'protected/'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Writes to protected/ require manual review."}}' >&2
  exit 2
fi
exit 0
```

2. `chmod +x .claude/hooks/your-hook.sh`
3. Add to `settings.json`: `{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": ".claude/hooks/your-hook.sh", "timeout": 5}]}`

Exit codes: `0` = allow, `2` = block. Matchers: `Bash`, `Edit`, `Write`, `Read`,
`Glob`, `Grep`, `WebFetch`, `Agent`, `NotebookEdit`, `mcp__*`. Combine with `|`.

---

### Creating a Conditional Rule

**When to use**: Guidance for specific file types only.

Create `.claude/rules/your-rule.md` with `paths:` frontmatter:

```yaml
---
paths:
  - "**/*.sql"
  - "**/migrations/**"
---
# SQL Rules
- All migrations must be reversible
- Never drop columns without a data migration
```

No `settings.json` change needed. Without `paths:`, the rule loads on every request
(unconditional) -- use sparingly, it costs tokens on every interaction.

---

### Adding a New Skill

**When to use**: A repeatable workflow worth a dedicated protocol.

Create `.claude/skills/your-skill.md`:

```yaml
---
description: "What this skill delivers"
when_to_use: "trigger keyword, invoke phrase"
allowed-tools: Read Glob Grep
model: sonnet
effort: normal
argument-hint: "[argument]"
---
# Skill Name
## Process
1. First step
2. Second step
## Constraints
- What this skill must not do
```

Frontmatter (~70 tokens) loads always. Body loads on invocation only.
Set `allowed-tools` to least privilege -- a review skill must not have `Write`.

---

### Sub-Project with CLAUDE.md Inheritance

**When to use**: A subdirectory needs its own configuration without losing the parent harness.

Create `your-subproject/CLAUDE.md` with sections: purpose, Tech Stack, Constraints,
Active Task. Claude Code loads it on top of the parent, overriding conflicts.
Do not duplicate parent rules -- reference by path if needed.

---

## Workflow Recipes

### Safe Deployment

**When to use**: Deploying to any live environment.

Invoke `/deploy [target]`. Claude proposes the command but does not run it.
You run it manually. `deploy-guard.sh` blocks any automatic execution attempt.

---

### Code Review with Evidence Hierarchy

**When to use**: Reviewing changes before merging.

Invoke `/code-review [file or description]`. The skill uses read-only tools.
Each finding is labeled FACT (file:line), INTERPRETATION (reasoning stated),
or ASSUMPTION (needs validation before acting).

---

### Debugging with 4-Phase Investigation

**When to use**: A failure with no obvious cause. Invoke `/debug [symptom]` or apply manually:

1. **Reproduce** -- exact steps that trigger the failure.
2. **Isolate** -- smallest path exhibiting it (Grep for error strings).
3. **Diagnose** -- FACT, INTERPRETATION, or ASSUMPTION. Confirm before fixing.
4. **Fix** -- minimal change. Re-run reproduction steps to verify.

---

### Token Budget Optimization

**When to use**: `npx cc-path budget` shows Layer 1 over 3K tokens.

1. Find unconditional rules: `grep -rL "^paths:" .claude/rules/`
2. Add `paths:` to rules that apply to specific file types.
3. Move rule bodies over 30 lines to `docs/` -- reference by path from the rule.
4. Trim CLAUDE.md: "sometimes relevant" → conditional rule; "workflow-specific" → skill.
5. Re-check: `npx cc-path budget` -- target under 3K tokens for Layer 1.
