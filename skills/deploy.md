---
description: "Safe deployment workflow with mandatory dry-run, pre-flight checks, and rollback plan"
when_to_use: "deploy, ship, release, push to production, go live, launch"
allowed-tools: Read Glob Grep Bash Agent
model: sonnet
effort: high
argument-hint: "[target environment or deployment description]"
---

# Deploy

Ship safely: dry-run first, confirm explicitly, document rollback before executing.

## Process

1. **Pre-flight**: verify all conditions pass before anything executes
2. **Dry-run**: show exactly what WOULD happen — no side effects
3. **Confirm**: hard confirm from user (irreversible + subjective per cognitive protection matrix)
4. **Execute**: run deploy commands through deploy-guard hook
5. **Verify**: confirm service is healthy post-deploy (health check, smoke test)
6. **Monitor**: watch logs for the first 5 minutes

## Pre-flight Checklist

- `git status` clean — no uncommitted changes
- Tests pass on current HEAD
- Branch is up to date with remote
- Target environment and version confirmed
- Rollback plan documented

## Constraints

- NEVER skip dry-run — dry-run is not optional
- NEVER deploy from a dirty working tree
- Document the rollback plan before executing, not after
- All deploy commands must pass through `deploy-guard.sh` (blocks `--prod`/`--force`)
- Hard confirm required: deployment is irreversible in production
- Reference: cognitive-protection.md matrix (irreversible + subjective = hard confirm)
