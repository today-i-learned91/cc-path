#!/bin/bash
# Circuit Breaker Gate — PreToolUse blocking check
# Blocks tool execution after 5+ consecutive failures
# Counterpart to circuit-breaker.sh (PostToolUseFailure)
# Resets on success via circuit-breaker-reset.sh (PostToolUse)

STATE_FILE="/tmp/claude-circuit-breaker-${CLAUDE_SESSION_ID:-shared}"
BLOCK_THRESHOLD=5

COUNT=0
[ -f "$STATE_FILE" ] && COUNT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -ge "$BLOCK_THRESHOLD" ]; then
  echo "[CIRCUIT BREAKER BLOCK] ${COUNT}회 연속 실패로 도구 실행 차단. 접근법을 완전히 변경하거나 사용자에게 보고하세요." >&2
  exit 2
fi

exit 0
