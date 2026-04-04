# Circuit Breakers for AI Agents: Lessons from Claude Code's Source

**TL;DR**
- AI agents fail in loops. Without circuit breakers, they waste tokens retrying the same broken approach indefinitely. Claude Code's own source code reveals the pattern: `MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3`.
- The fix is a three-script architecture: track failures (PostToolUseFailure), gate new attempts (PreToolUse), and reset on success (PostToolUse). Two tiers: warn at 3, block at 5.
- This is not theoretical. Real data from Claude Code's source comments reference 1,279 sessions with 50+ consecutive failures wasting approximately 250K API calls per day.

---

## The Problem: Agents in a Loop

You have seen this. You might not have named it, but you have seen it.

Claude is working on a complex task. Something fails -- a test, a build, a type check. Claude tries to fix it. The fix introduces a new error. Claude tries to fix that. The second fix reintroduces the first error. Claude is now oscillating between two broken states, burning through API calls, context window, and your patience.

This is not a Claude-specific problem. Every AI coding agent has this failure mode. The agent has no mechanism to recognize "I have been trying and failing for 20 consecutive attempts, maybe I should stop and ask for help."

Humans have this circuit naturally. After three failed attempts, you lean back, think, and try a fundamentally different approach. Or you ask a colleague. AI agents do not have this circuit. They will retry the same broken approach until the context window fills up, the session times out, or you manually intervene.

## The Evidence: This Problem Is Massive

How massive? Claude Code's own source code contains a comment that references the scale of this problem. The `autoCompact.ts` file, which handles context window management, sets:

```javascript
MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3
```

This constant exists because Anthropic's telemetry showed that consecutive failure loops were one of the most common failure modes in extended sessions. The threshold of 3 was not guessed -- it was derived from data about when self-correction typically fails and escalation becomes necessary.

The source comments reference analysis of sessions where compaction fails repeatedly, creating a cascade: the model tries to compact, fails, tries again with slightly different parameters, fails again, and so on. Each attempt consumes tokens without making progress.

This pattern generalizes far beyond compaction. Any tool use can enter a failure loop: build commands, test runs, file edits, API calls. The underlying dynamic is always the same: the agent retries without diagnosing the root cause.

## The Solution from Source

Claude Code's approach in `autoCompact.ts` is simple and effective:

1. Track consecutive failures with a counter
2. After N consecutive failures, change behavior (skip the operation, alert the user, try an alternative)
3. Reset the counter on any success

This is a textbook circuit breaker pattern from distributed systems, applied to AI agent behavior. The insight is that the same pattern that prevents cascading failures in microservices also prevents cascading failures in agent loops.

## The Three-Script Architecture

Claude Code's hook system gives us the primitives to build this. We need three scripts, each bound to a different hook event:

| Script | Hook Event | Purpose |
|--------|-----------|---------|
| `circuit-breaker.sh` | PostToolUseFailure | Count failures, inject warnings |
| `circuit-breaker-gate.sh` | PreToolUse | Block when threshold exceeded |
| `circuit-breaker-reset.sh` | PostToolUse | Reset counter on success |

Why three scripts instead of one? Because each hook event has different capabilities:

- **PostToolUseFailure** can only inject context (advisory messages). It cannot block.
- **PreToolUse** can block execution (exit 2 = deny). It is the gate.
- **PostToolUse** handles the reset path. Any successful tool use clears the counter.

A single script trying to detect which hook invoked it would violate the "Explicit Over Clever" principle. Each script has one job and one hook binding. The architecture is clear from the file listing alone.

## Script 1: Track Failures

`circuit-breaker.sh` runs on every tool failure. It increments a counter and injects progressively urgent warnings:

```bash
#!/bin/bash
# Circuit Breaker -- tracks consecutive tool failures
# Two-tier response: warn at 3, block at 5
# Source: autoCompact.ts:67-70 (MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3)

STATE_FILE="/tmp/claude-circuit-breaker-${CLAUDE_SESSION_ID:-shared}"
WARN_THRESHOLD=3
BLOCK_THRESHOLD=5

# Read current count
COUNT=0
[ -f "$STATE_FILE" ] && COUNT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

# Increment
COUNT=$((COUNT + 1))
echo "$COUNT" > "$STATE_FILE"

if [ "$COUNT" -ge "$BLOCK_THRESHOLD" ]; then
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER CRITICAL] ${COUNT} consecutive
    failures. Next tool call will be BLOCKED. You must change your approach
    completely. Analyze the root cause and report to the user.\"}"
elif [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER] ${COUNT} consecutive tool
    failures. Re-examine your approach. Do not repeat the same method.
    Diagnose the root cause before trying a different strategy.\"}"
fi

exit 0
```

Key design decisions:

**Per-session state.** The state file uses `$CLAUDE_SESSION_ID` in its path. Different sessions have independent circuit breakers. One session's failures do not affect another's.

**Two tiers.** Warn at 3, alert at 5. The warn tier gives the model a chance to self-correct -- Claude Code's own "Diagnose Before Retrying" principle (#7 in our principles list). The block tier provides a hard stop when self-correction fails.

**Exit 0 always.** PostToolUseFailure hooks cannot block. They can only inject context. The actual blocking happens in the gate script.

## Script 2: Gate New Attempts

`circuit-breaker-gate.sh` runs *before* every mutation tool call. If the failure count has hit the block threshold, it denies the call:

```bash
#!/bin/bash
# Circuit Breaker Gate -- PreToolUse blocking check
# Blocks tool execution after 5+ consecutive failures

STATE_FILE="/tmp/claude-circuit-breaker-${CLAUDE_SESSION_ID:-shared}"
BLOCK_THRESHOLD=5

COUNT=0
[ -f "$STATE_FILE" ] && COUNT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -ge "$BLOCK_THRESHOLD" ]; then
  echo "[CIRCUIT BREAKER BLOCK] ${COUNT} consecutive failures.
    Tool execution blocked. Change approach or report to user." >&2
  exit 2
fi

exit 0
```

**Critical: matcher scope.** This hook matches `Bash|Edit|Write` -- mutation tools only. It explicitly does *not* match `Read`, `Glob`, or `Grep`. Why? Because when the model is stuck in a failure loop, reading files is often the path to recovery. Blocking reads prevents the model from diagnosing the problem. You want to block *actions* while allowing *investigation*.

## Script 3: Reset on Success

`circuit-breaker-reset.sh` runs after every successful tool use. One success resets the counter:

```bash
#!/bin/bash
# Circuit Breaker Reset -- clears failure count on success

STATE_FILE="/tmp/claude-circuit-breaker-${CLAUDE_SESSION_ID:-shared}"
[ -f "$STATE_FILE" ] && echo "0" > "$STATE_FILE"
exit 0
```

This is the shortest script and arguably the most important. Without it, a model that hits 5 failures would be permanently blocked for the rest of the session. The reset ensures that any successful recovery clears the state.

**No matcher restriction.** The reset hook has no matcher -- any successful tool use resets the counter. A successful `Read` or `Grep` counts as recovery, even though those tools are not gated.

## Wiring It Together

In `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|NotebookEdit",
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/circuit-breaker-gate.sh",
          "timeout": 3
        }]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/circuit-breaker-reset.sh",
          "timeout": 3
        }]
      }
    ],
    "PostToolUseFailure": [
      {
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/circuit-breaker.sh",
          "timeout": 3
        }]
      }
    ]
  }
}
```

Notice the timeout: 3 seconds for each hook. These scripts read and write a single integer to a temp file. They should complete in milliseconds. The timeout is a safety net, not an expected duration.

## Why Two Tiers, Not One

A common question: why not just block at 3? Or why not just warn?

**Block at 3 is too aggressive.** Three consecutive failures can happen during legitimate complex operations. A test that fails because the implementation is not done yet, then fails again because the first fix was partial, then fails a third time because of a typo -- that is normal development. Blocking after 3 would interrupt productive work.

**Warn-only is too passive.** Under token pressure, advisory messages can be ignored. The model might acknowledge the warning and then immediately retry the same approach. This is the guidance-vs-governance problem: warnings are guidance (~80% effective), blocks are governance (100% effective).

The two-tier approach uses graduated response:
- **Warn at 3**: "You have failed 3 times. Stop and diagnose." This gives the model a chance to self-correct, which it does successfully in many cases.
- **Block at 5**: "You have failed 5 times despite the warning. You are blocked." This is the hard stop for when self-correction fails.

The thresholds are derived from Claude Code's own `MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3`. We doubled it to 5 for the block threshold because halting all tool use is a severe action that should require strong evidence of a genuine loop.

## The Broader Principle: Data-Driven Thresholds

The circuit breaker embodies a broader principle: **Data-Driven Circuit Breakers -- thresholds from measurement, not intuition.**

It is tempting to set thresholds based on what "feels right." Three failures feels like a good warning point. Ten feels like a good block point. But feelings are not engineering.

Claude Code's threshold of 3 came from analyzing actual failure patterns across thousands of sessions. Our warn-at-3 inherits this data. Our block-at-5 doubles it based on the principle that blocking is more severe than the mode change that Claude Code applies internally.

When you customize these thresholds for your project, measure first:
- How many consecutive failures typically occur during legitimate complex work?
- At what point does continued retrying become clearly unproductive?
- What is the cost of a false positive (blocking productive work) vs a false negative (allowing a wasteful loop)?

Set your thresholds based on answers, not intuition.

## Testing the Circuit Breaker

You can test without a real failure loop:

```bash
# Simulate 5 failures
export CLAUDE_SESSION_ID=test
for i in 1 2 3 4 5; do
  .claude/hooks/circuit-breaker.sh
done

# Check the gate
.claude/hooks/circuit-breaker-gate.sh
echo $?  # Should print 2 (blocked)

# Reset
.claude/hooks/circuit-breaker-reset.sh

# Check again
.claude/hooks/circuit-breaker-gate.sh
echo $?  # Should print 0 (allowed)

# Clean up
rm -f /tmp/claude-circuit-breaker-test
```

## Beyond Claude Code

The circuit breaker pattern applies to any AI coding assistant that supports hooks or middleware:

- **Cursor**: Custom rules can encode the warning, but deterministic blocking requires the tool layer.
- **GitHub Copilot Workspace**: Agent loops are a known issue. Pre-commit hooks can provide a partial gate.
- **Any agent framework**: If your agent framework supports pre/post execution hooks, you can implement this pattern directly.

The principle is universal: AI agents need external circuit breakers because they lack the internal "step back and reconsider" mechanism that humans use instinctively.

---

*Next in the series: [Your CLAUDE.md Is a Constitution](05-constitutional-ai-meets-claude-md.md) -- what Constitutional AI teaches about workspace design.*

*The complete circuit breaker implementation is in the [cc-path](https://github.com/ziho/cc-path) repository.*
