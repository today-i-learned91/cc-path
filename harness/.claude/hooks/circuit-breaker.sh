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
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER CRITICAL] ${COUNT}회 연속 실패 — 다음 도구 호출이 차단됩니다. 반드시 접근법을 완전히 변경하세요. 근본 원인을 분석하고 사용자에게 상황을 보고하세요.\"}"
elif [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
  echo "{\"additionalContext\":\"[CIRCUIT BREAKER] ${COUNT}회 연속 도구 실패. 접근법을 재검토하세요. 동일한 방법을 반복하지 말고 근본 원인을 분석한 후 다른 전략을 시도하세요.\"}"
fi

exit 0
