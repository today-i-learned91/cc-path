---
paths:
  - CLAUDE.md
  - .claude/**
  - docs/**
---

# Document Management Principles

Based on Anthropic's philosophy and Claude Code's 7 design principles.

## File Creation Rules

- Create new files **only when existing files cannot solve the need**
- Search with Grep before creating — avoid duplication
- If one file covers two concerns, consider splitting

| Type | Location | Loading |
|------|----------|---------|
| System behavior | `CLAUDE.md` | Always |
| Dev conventions | `.claude/CLAUDE.md` | Always |
| Conditional rules | `.claude/rules/*.md` + `paths:` | On file access |
| Unconditional rules | `.claude/rules/*.md` (no paths) | Always |
| Workflows | `.claude/skills/*.md` | Frontmatter only; body on invocation |
| Reference docs | `docs/` | Explicit Read only |
| Sub-projects | `name/CLAUDE.md` | On CWD entry |

## Naming Conventions

- `docs/`: **UPPER-KEBAB-CASE** (`ARCHITECTURE.md`)
- `.claude/rules/`, `.claude/skills/`: **lower-kebab-case**
- Sub-projects: `YYYY-MM-DD-lower-kebab-case/`
- No case-only-different filenames in same directory (macOS collision)

## Size Limits (Token Budget)

| Target | Recommended |
|--------|-------------|
| CLAUDE.md (root) | 80 lines / 4KB |
| .claude/CLAUDE.md | 60 lines / 3KB |
| .claude/rules/ each | 30 lines / 1.5KB |
| docs/ each | 800 lines / 40KB |

## Single Source of Truth

- **One fact in one place** — reference by path, never copy content
- Periodic check: core principles must not be redefined in multiple files

## Lifecycle

1. **Deprecate**: add `<!-- DEPRECATED: YYYY-MM-DD reason -->` comment
2. **Archive**: after 30 days with no references, move to `docs/archive/`
3. **Delete**: after 60 days in archive with no references, remove
4. Detection: 90+ days without git changes + no references
