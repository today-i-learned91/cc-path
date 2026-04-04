---
paths:
  - "*.py"
  - "*.pyi"
  - "pyproject.toml"
  - "requirements*.txt"
---
# Python Conventions

## Style and Tooling

- Use `ruff` for both formatting and linting — not flake8/black separately
- Run `ruff check --fix` and `ruff format` before commit
- PEP 8 compliance is enforced by ruff, not by convention alone

## Type Hints

- Annotate all function signatures — parameters and return types
- Add `from __future__ import annotations` at the top for forward references
- Use `X | None` over `Optional[X]` (Python 3.10+)

## Imports

- Order: stdlib → third-party → local, separated by blank lines
- One import per line — aids diffs and conflict resolution
- Never use wildcard imports (`from module import *`)

## Environment and Dependencies

- Always use `venv` or `uv` — never install packages globally
- Declare dependencies in `pyproject.toml`, not `setup.py`
- Pin versions in `requirements.txt` for deployments; ranges in `pyproject.toml` for libraries

## Testing

- Use `pytest` — not `unittest`
- Prefer fixtures over setup/teardown methods
- Name tests to describe behavior: `test_returns_empty_list_when_no_input`

## Error Handling

- Catch specific exceptions — never bare `except:`
- Let exceptions propagate unless you can meaningfully handle them at that boundary

## Strings

- F-strings over `.format()` or `%` formatting
