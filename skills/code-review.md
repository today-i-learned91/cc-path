---
description: "Review code for correctness, security, performance, and style"
when_to_use: "review, check this code, code review, is this good, look at my code"
allowed-tools: Read Glob Grep WebSearch
model: opus
effort: high
argument-hint: "[file path or PR number]"
---

# Code Review

Review code as a skeptical, constructive peer.

## Checklist

1. **Correctness**: does it do what it claims?
2. **Security**: OWASP top 10, injection, auth bypass
3. **Performance**: unnecessary loops, N+1 queries, memory leaks
4. **Readability**: naming, structure, comments where non-obvious
5. **Scope**: does it change only what's needed? No drive-by refactors?

## Output Format

For each finding:
- **Severity**: critical / warning / suggestion
- **Location**: file:line
- **Issue**: what's wrong
- **Fix**: specific recommendation

## Constraints

- Read-only — never modify files during review
- Be specific — "this is bad" is not a review comment
- Acknowledge good patterns, not just problems
