# Your CLAUDE.md Is Not Enough: Why AI Safety Needs Code, Not Text

**TL;DR**
- CLAUDE.md instructions work about 80% of the time. Under token pressure (long sessions, post-compaction), the model skims or ignores them. That remaining 20% is where incidents happen.
- Safety-critical rules must be hooks -- shell scripts that run outside the model's context and cannot be overridden. Exit code 2 blocks the action with 100% reliability.
- The principle: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)." This is not a suggestion. It is an architectural decision with real consequences.

---

## The Failure Mode Nobody Warns You About

Here is a scenario that has happened to every long-session Claude Code user:

Turn 1: You tell Claude "never force-push to main." Claude acknowledges. Your CLAUDE.md says the same thing. Everything works.

Turn 15: Claude is deep in a complex refactor. It reads files, writes code, runs tests. The context window fills up. Claude Code auto-compacts, summarizing older messages to make room.

Turn 47: Claude finishes a fix and decides to push. The instruction about force-pushing was in the compacted region. The model's summary preserved the gist but not the specific constraint. Claude runs `git push --force origin main`.

Your main branch is rewritten. Your teammates' work is gone.

This is not a hypothetical. It is how attention-based architectures degrade under load. The model does not "decide" to ignore your instruction. The instruction's influence fades as it gets farther from the current context window, especially after compaction. This is physics, not disobedience.

## The Solution: Hooks as Deterministic Governance

Claude Code provides a hook system that executes shell scripts at specific points in the tool-use lifecycle:

- **PreToolUse**: Runs *before* the model executes a tool. Can block (exit 2), allow (exit 0), or modify behavior.
- **PostToolUse**: Runs *after* successful tool execution. Used for logging, formatting, cleanup.
- **PostToolUseFailure**: Runs after a tool fails. Used for tracking failure patterns.

The critical insight: hooks run *outside* the model's context. The model cannot see them, reason about them, or override them. A PreToolUse hook that exits with code 2 blocks the tool call unconditionally, regardless of what the model thinks it should do.

This is the difference between guidance and governance:

```
CLAUDE.md:  "Never force-push to main."
            Claude follows this ~80% of the time.
            Under token pressure, compliance drops.
            The model can rationalize exceptions.

Hook:       deploy-guard.sh exits 2 on --force patterns.
            Works 100% of the time.
            No context cost.
            Cannot be overridden by the model.
```

## Real Example: deploy-guard.sh

Here is the deploy guard from our harness:

```bash
#!/bin/bash
# Deploy Guard — blocks production deployments
# PreToolUse hook on Bash matcher
# Exit 0 = allow, Exit 2 = block

COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

PROD_PATTERNS=(
  'vercel --prod'
  'vercel.*--prod'
  'firebase deploy'
  '--force'
  'git push.*--force'
  'git push.*-f '
  'npm publish'
  'supabase db push'
)

for pattern in "${PROD_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse",
      "permissionDecision":"deny",
      "permissionDecisionReason":"Production deployment blocked.
      Run manually after confirmation."}}' >&2
    exit 2
  fi
done

exit 0
```

This script reads the tool input via `$CLAUDE_TOOL_INPUT`, extracts the bash command, and pattern-matches against dangerous operations. If it matches, it writes a JSON denial to stderr and exits with code 2. The tool call never executes.

Wire it in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/deploy-guard.sh",
          "timeout": 5
        }]
      }
    ]
  }
}
```

The `matcher: "Bash"` is deliberate. Only the Bash tool runs shell commands, so only the Bash tool needs deploy guarding. Matching too broadly (e.g., all tools) adds latency without benefit.

## Real Example: Input Sanitizer

External data sources -- MCP tool results, web fetches -- can contain adversarial content designed to manipulate the model. A CLAUDE.md instruction to "be careful with external data" is guidance. A hook that detects injection patterns is governance:

```bash
#!/bin/bash
# Input Sanitizer — detects prompt injection in tool inputs
# PreToolUse on Bash|WebFetch|mcp__* matchers

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$TOOL_INPUT" ] && exit 0

# Pattern 1: System prompt override attempts
if echo "$TOOL_INPUT" | grep -qiE \
  "(ignore (all |previous |prior )?instructions|you are now|new system prompt)"; then
  echo '{"decision":"ask","reason":"[INPUT SANITIZER] Prompt injection
    pattern detected. Please review the input."}'
  exit 0
fi

# Pattern 2: Data exfiltration attempts
if echo "$TOOL_INPUT" | grep -qiE \
  "(curl.*\|.*base64|wget.*-O-.*\||nc [0-9]|/dev/tcp/)"; then
  echo '{"decision":"ask","reason":"[INPUT SANITIZER] Data exfiltration
    pattern detected. Confirmation required."}'
  exit 0
fi

exit 0
```

Notice the response strategy: the sanitizer uses `"decision":"ask"` (soft block, user decides) rather than hard denial. This is deliberate. False positives on legitimate content are likely, so the user makes the final call. Defense in depth with human override, not blind automation.

## The Decision Framework: What Goes Where

Here is how to decide whether something belongs in CLAUDE.md or in a hook:

| Question | If Yes | If No |
|----------|--------|-------|
| Would violation cause data loss or security breach? | Hook (hard block) | Continue |
| Would violation affect systems outside this session? | Hook (hard block) | Continue |
| Is the constraint contextual or subjective? | CLAUDE.md (guidance) | Continue |
| Does the rule need 100% compliance, not 80%? | Hook | CLAUDE.md |
| Is the rule about *how to think* vs *what not to do*? | CLAUDE.md | Consider hook |

Concrete examples:

| Rule | Placement | Why |
|------|-----------|-----|
| "Never force-push to main" | **Hook** | Violation is irreversible, affects shared systems |
| "Read code before modifying it" | **CLAUDE.md** | Contextual guidance about thinking approach |
| "Block production deployments" | **Hook** | 80% compliance on deploys means 1-in-5 incidents |
| "Use conventional commit messages" | **CLAUDE.md** | Violation is annoying but reversible |
| "Classify claims as FACT/INTERPRETATION/ASSUMPTION" | **CLAUDE.md** | Thinking framework, not hard constraint |
| "Block data exfiltration patterns" | **Hook** (soft) | Security concern, but needs human override for false positives |

## The Complementary Relationship

Hooks without guidance create confused behavior. Claude gets blocked but does not understand why, leading to workaround attempts. Guidance without hooks creates aspirational safety -- it works until it does not.

You need both:

```
CLAUDE.md (guidance):
  "Deployment to production requires explicit user confirmation.
   Use dry-run mode before any live deployment."

  This teaches Claude WHY deployments are sensitive.
  It shapes default behavior 80% of the time.

deploy-guard.sh (governance):
  exit 2 on production deployment patterns.

  This catches the 20% where guidance fails.
  It blocks unconditionally.
```

The model understands the principle (from CLAUDE.md) and works within it. The hook catches the cases where understanding fails. This mirrors how organizations work: policies (guidance) set expectations, and access controls (governance) enforce boundaries.

## Common Mistakes

**1. Putting safety rules only in CLAUDE.md.** "Never delete the production database" as a CLAUDE.md instruction is a hope, not a safeguard. If the consequence of violation is severe and irreversible, it must be a hook.

**2. Hooking everything.** Not every rule needs 100% enforcement. Coding style preferences in hooks add latency and create false positives. Reserve hooks for safety-critical operations.

**3. Hard-blocking when you should soft-block.** The input sanitizer uses `"decision":"ask"` because false positives on external content are expected. A hard block on legitimate MCP results breaks workflows. Match the response to the confidence level.

**4. Forgetting the matcher scope.** Deploy guard matches only `Bash` because only Bash runs shell commands. Circuit breaker gate matches `Bash|Edit|Write` -- mutation tools only. Never match `Read` or `Grep` -- blocking reads during a failure spiral prevents the model from recovering.

**5. No timeout.** Hooks have a `timeout` field (in seconds). A hook that hangs blocks the entire session. Keep timeouts short: 3-5 seconds for most hooks.

## The Anthropic Principle

This guidance-vs-governance split is not something we invented. It mirrors Anthropic's own architecture:

- **Constitutional AI** uses principles (guidance) for self-critique and RLHF constraints (governance) for hard boundaries. Neither alone is sufficient.
- **Responsible Scaling Policy** defines pre-committed thresholds: "If capability X, then safeguard Y." These are hooks, not suggestions.
- **Claude Code's permission pipeline** in `Tool.ts` runs every tool call through a 5-step gauntlet: `checkPermissions > Settings > Sandbox > PermissionMode > Hooks`. The model's intent is just one input. The system has the final say.

The principle we encode: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)." This is the single most important insight in harness engineering. Everything else follows from it.

## Try It Yourself

Start with one hook. The deploy guard is the easiest:

```bash
# Create the hook
mkdir -p .claude/hooks
cat > .claude/hooks/deploy-guard.sh << 'SCRIPT'
#!/bin/bash
COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0
for pattern in '--force' 'git push.*-f ' 'npm publish'; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by deploy guard."}}' >&2
    exit 2
  fi
done
exit 0
SCRIPT
chmod +x .claude/hooks/deploy-guard.sh

# Wire it in settings.json
cat > .claude/settings.json << 'JSON'
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type":"command","command":".claude/hooks/deploy-guard.sh","timeout":5}]
    }]
  }
}
JSON
```

Then ask Claude to run `git push --force origin main`. It will be blocked. That is governance.

---

*Next in the series: [From Machines of Loving Grace to settings.json](03-anthropic-philosophy-in-practice.md) -- how Anthropic's published philosophy maps to concrete workspace design decisions.*

*The full harness with all hooks is available at [claude-code-harness-engineering](https://github.com/ziho/claude-code-harness-engineering).*
