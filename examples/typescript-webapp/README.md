# Example: TypeScript Webapp

Minimal Express/TypeScript app with cc-path harness applied.

## Setup

```bash
cp .env.example .env  # set API_KEY
npm install
npm run dev
```

## Endpoints

- `GET /health` — liveness check, no auth
- `GET /items` — list items (`X-API-Key` header required)
- `POST /items` — create item (`X-API-Key` header required), body: `{"name": "...", "description": "..."}`

## Harness Patterns Demonstrated

- `CLAUDE.md` declares stack, constraints, and active task
- `.env.example` templates secrets — never committed to git
- Fail-closed startup: missing `API_KEY` calls `process.exit(1)` before binding the port
