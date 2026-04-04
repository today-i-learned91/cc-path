# cc-path CLI

Health check and token budget analyzer for Claude Code harness files.

## Usage

```bash
npx cc-path doctor    # Scan harness health (scored 0-10)
npx cc-path budget    # Estimate token budget per context layer
```

## Commands

### `doctor`

Scans the current directory for Claude Code configuration files and produces a health score out of 10.

**Checks performed:**
- `CLAUDE.md` exists and is under 80 lines
- `.claude/CLAUDE.md` exists and is under 60 lines
- `.claude/rules/` — file count, conditional vs unconditional
- `.claude/hooks/` — file count, deploy-guard, circuit-breaker
- `.claude/skills/` — file count, frontmatter quality
- `.claude/settings.json` — exists, hooks wired

### `budget`

Estimates token cost for each harness file across three layers:

| Layer | Files | Loading |
|-------|-------|---------|
| Layer 1 | `CLAUDE.md`, `.claude/CLAUDE.md`, unconditional rules | Always in context |
| Layer 2 | Rules with `paths:` frontmatter | Loaded when matching file accessed |
| Layer 3 | Skills | Frontmatter only; body on invocation |
| Governance | Hooks | Zero context cost (shell scripts) |

## Requirements

- Node.js 18+
- Zero external dependencies
