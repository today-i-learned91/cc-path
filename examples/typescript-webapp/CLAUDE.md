# TypeScript Webapp Example

Minimal Express app demonstrating cc-path harness in a TypeScript project.
Shows how CLAUDE.md + package.json + env safety apply to a Node/TS stack.

## Tech Stack
- Node.js 20+
- TypeScript 5+
- Express 4
- dotenv (env loading)

## Constraints
- No database — in-memory store only (example scope)
- No auth middleware beyond env key check
- No frontend bundler — API-only skeleton
- Zero personal data in code or comments

## Active Task
Serve as a reference example for cc-path harness adoption in TypeScript projects.

## Inherits From Parent
Parent harness rules apply automatically:
- Secrets in `.env` only — never hardcoded (see `.env.example`)
- Fail closed: missing env var logs error and exits on startup
- English for all harness files
