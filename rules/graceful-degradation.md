# Graceful Degradation

When an external tool or MCP server fails, follow the fallback chain
instead of failing the task. Inspired by Anthropic's circuit breaker
pattern (autoCompact.ts) and Boris Cherny's "do the simple thing first."

## Fallback Chains

### MCP Tool Failure
1. Retry once with simplified input
2. Fall back to built-in equivalent (see table below)
3. Report limitation to user, suggest manual alternative

### Built-in Fallback Table

| Failed MCP Tool | Fallback | Notes |
|-----------------|----------|-------|
| knowledge_search | Grep + Glob in project | Local search |
| slack_* | Report to user | Cannot substitute |
| gmail_* | Report to user | Cannot substitute |
| python_repl | Bash(python3 ...) | Direct execution |
| lsp_* | Grep + Read | Manual symbol lookup |

### External API Failure
1. Check if cached/stale result is acceptable (Principle #15)
2. Retry with exponential backoff (max 3 attempts)
3. If circuit breaker tripped (5+ failures): stop retrying, report

### File System Failure
1. Verify path exists (Glob)
2. Check permissions (ls -la)
3. Try alternative path or report

## Anti-Patterns

- Never silently swallow errors — always report what failed and why
- Never retry the exact same call more than once (Principle #7: Diagnose Before Retrying)
- Never fall back to a less-safe alternative without user awareness
