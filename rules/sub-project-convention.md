---
paths:
  - "**/CLAUDE.md"
  - "*/src/**"
  - "*/package.json"
---

# Sub-Project Structure Convention

When creating or working in a sub-project directory:

## Required Structure

Every sub-project MUST have a `CLAUDE.md` at its root:

```markdown
# Project Name

Brief purpose (1-2 sentences).

## Tech Stack
- Language/framework and version
- Key dependencies

## Constraints
- Performance budgets, browser support, etc.

## Active Task
Current focus area.
```

## Optional Files

- `.claudeignore` — project-specific ignore patterns
- `CLAUDE.local.md` — private notes not committed to git

## Naming Convention

- Dated projects: `YYYY-MM-DD-descriptive-name/`
- Ongoing projects: `descriptive-name/`
- Use lowercase-kebab-case for directory names

## Inheritance

Sub-project CLAUDE.md inherits all parent workspace rules automatically.
Only add project-specific overrides — do not duplicate parent rules.
