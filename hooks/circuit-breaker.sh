#!/bin/bash
# Circuit Breaker — tracks consecutive tool failures
# Two-tier response: warn at 3, block at 5
# Inspired by autoCompact.ts:67-70: MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3
#
# Used by PostToolUseFailure hook
# Writes count to temp file, injects warning via additionalContext

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
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER CRITICAL] ${COUNT}consecutive failures — next tool call will be blocked. Change your approach entirely. Analyze root cause and report to user.\"}"
elif [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER] ${COUNT}consecutive tool failures. Re-evaluate your approach. Diagnose the root cause before trying a different strategy.\"}"
fi

exit 0
