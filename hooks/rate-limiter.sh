#!/bin/bash
# Rate Limiter — prevents excessive external API calls
# PreToolUse hook: tracks call frequency per tool type
# Aligned with circuit-breaker pattern (data-driven thresholds)

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TRACK_DIR="/tmp/claude-ratelimit-${CLAUDE_SESSION_ID:-shared}"
LOG_FILE="${TRACK_DIR}/calls.jsonl"

# Only track external-facing tools
case "$TOOL_NAME" in
  WebFetch|WebSearch) THRESHOLD=10 ;;
  mcp__*)            THRESHOLD=20 ;;
  *) exit 0 ;;
esac

mkdir -p "$TRACK_DIR"
chmod 700 "$TRACK_DIR"

# Current timestamp in epoch seconds
NOW=$(date +%s)
WINDOW=60

# Append current call
echo "{\"ts\":${NOW},\"tool\":\"${TOOL_NAME}\"}" >> "$LOG_FILE"

# Clean up entries older than 60 seconds and count recent calls for this tool
CUTOFF=$((NOW - WINDOW))
RECENT_COUNT=0
TEMP_FILE="${LOG_FILE}.tmp.$$"

while IFS= read -r line; do
  # Extract timestamp (simple numeric extraction after "ts":)
  ts=$(echo "$line" | grep -o '"ts":[0-9]*' | grep -o '[0-9]*')
  [ -z "$ts" ] && continue
  # Keep only entries within the window
  if [ "$ts" -ge "$CUTOFF" ] 2>/dev/null; then
    echo "$line" >> "$TEMP_FILE"
    # Count calls matching this tool
    if echo "$line" | grep -q "\"tool\":\"${TOOL_NAME}\""; then
      RECENT_COUNT=$((RECENT_COUNT + 1))
    fi
  fi
done < "$LOG_FILE"

# Replace log with cleaned version
if [ -f "$TEMP_FILE" ]; then
  mv "$TEMP_FILE" "$LOG_FILE"
else
  : > "$LOG_FILE"
fi

# Check threshold
if [ "$RECENT_COUNT" -gt "$THRESHOLD" ]; then
  echo "{\"decision\":\"ask\",\"reason\":\"[RATE LIMITER] ${RECENT_COUNT} calls to ${TOOL_NAME} in last 60s. Slow down?\"}"
fi

exit 0
