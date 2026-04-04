# Python API Example

Minimal FastAPI app demonstrating cc-path harness in a Python project.
Shows how CLAUDE.md + .env.example + circuit-breaker safety apply to a Python stack.

## Tech Stack
- Python 3.11+
- FastAPI 0.110+
- Uvicorn (ASGI server)
- python-dotenv (env loading)

## Constraints
- No database — in-memory store only (example scope)
- No auth — placeholder API key check via env var
- Response time < 100ms for all endpoints
- Zero personal data in code or comments

## Active Task
Serve as a reference example for cc-path harness adoption in Python projects.

## Inherits From Parent
Parent harness rules apply automatically:
- Secrets in `.env` only — never hardcoded (see `.env.example`)
- Fail closed: missing env var raises startup error, not runtime error
- English for all harness files
