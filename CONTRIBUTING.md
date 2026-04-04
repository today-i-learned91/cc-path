# Contributing to cc-path

Contributions are welcome. This document explains how.

## How to Contribute

1. **Fork** the repository on GitHub.
2. **Create a branch** from `main` (`git checkout -b your-feature`).
3. **Make your changes** in `harness/`, `docs/`, `examples/`, or `blog/`.
4. **Test your changes** -- copy the modified harness into a real project and verify Claude Code behaves as expected.
5. **Submit a PR** with a clear description of what changed, why (with source citation), and how you tested it.

## What We Welcome

- **Skills** -- new `.claude/skills/*.md` workflows
- **Hooks** -- governance scripts for `.claude/hooks/`
- **Rules** -- conditional rules for `.claude/rules/`
- **Documentation** -- improvements to `docs/`, corrections, better examples
- **Blog posts** -- companion articles in `blog/`
- **Translations** -- localized versions of docs (place in `docs/i18n/`)
- **Examples** -- sub-project templates in `examples/`

## Standards

### Every claim needs a source

No vibes. Link to the Anthropic paper, Claude Code source `file:line`, or blog post. Unsourced claims will be flagged in review.

### Respect the token budget

| Layer | Budget |
|-------|--------|
| Layer 1 (CLAUDE.md) | Under 3K tokens |
| Layer 2 (rules) | Under 1.5KB each |
| Layer 3 (skills) | Frontmatter under 70 tokens |

### Match existing patterns

Read the harness files before contributing. Follow the same naming conventions, frontmatter format, and structure.

## Skill Contribution Template

New skills go in `harness/.claude/skills/`. Use this frontmatter format:

```yaml
---
name: your-skill-name
description: One-line description of what it does.
paths:
  - "relevant/path/pattern/**"
---

Skill body loaded on invocation. Keep it focused.
```

## Code of Conduct

Aligned with Anthropic's published values:

- **Be forthright.** Share relevant information even if not explicitly asked.
- **Be calibrated.** Distinguish facts from interpretations from assumptions. Say "I don't know" when you don't.
- **Be helpful.** Prioritize contributions that make the project genuinely better for users, not just larger.
- **Be respectful.** Critique ideas, not people. Assume good intent.

## Review Process

1. A maintainer will review your PR within a week.
2. We check: source citations present, token budget respected, harness tested in a real project.
3. Small, focused PRs are reviewed faster than large ones.
4. If changes are requested, address them in new commits (do not force-push).

## Questions?

Open an issue or start a discussion. There are no stupid questions -- only undocumented answers.
