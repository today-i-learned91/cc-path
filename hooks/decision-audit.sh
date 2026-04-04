#!/bin/bash
# Decision Audit Trail — logs tool usage for transparency
# PostToolUse hook: appends structured entries to session log
# Enables AI Dependency Check from cognitive-protection.md

LOG_DIR="/tmp/claude-audit-${CLAUDE_SESSION_ID:-shared}"
LOG_FILE="${LOG_DIR}/decisions.jsonl"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOOL_NAME_RAW="${CLAUDE_TOOL_NAME:-unknown}"
# Sanitize tool name for safe filesystem and JSON use (prevent path traversal via MCP tool names)
TOOL_NAME=$(echo "$TOOL_NAME_RAW" | tr -cd 'a-zA-Z0-9_-')

# Append entry
echo "{\"ts\":\"${TIMESTAMP}\",\"tool\":\"${TOOL_NAME}\",\"session\":\"${CLAUDE_SESSION_ID:-shared}\"}" >> "$LOG_FILE"

# --- AI Dependency Check: per-tool consecutive usage tracking ---
# Track consecutive same-tool usage with a counter file per tool.
# The old approach (tail -5 | grep -c) missed interleaved patterns.
COUNTER_FILE="${LOG_DIR}/.counter_${TOOL_NAME}"

# Check the PREVIOUS tool (second-to-last entry, since we just appended the current one)
PREV_TOOL=""
if [ -f "$LOG_FILE" ]; then
  LINE_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
  if [ "$LINE_COUNT" -ge 2 ]; then
    PREV_TOOL=$(tail -2 "$LOG_FILE" | head -1 | grep -o '"tool":"[^"]*"' | head -1 | sed 's/"tool":"//;s/"//')
  fi
fi

# Read current consecutive count, increment or reset
if [ "$PREV_TOOL" = "$TOOL_NAME" ] && [ -f "$COUNTER_FILE" ]; then
  CONSECUTIVE=$(cat "$COUNTER_FILE")
  CONSECUTIVE=$((CONSECUTIVE + 1))
else
  CONSECUTIVE=1
fi

echo "$CONSECUTIVE" > "$COUNTER_FILE"

# Alert at 3+ consecutive uses of mutation tools
if [ "$CONSECUTIVE" -ge 3 ]; then
  case "$TOOL_NAME" in
    Edit|Write|Bash|NotebookEdit)
      echo "{\"additionalContext\":\"[AI DEPENDENCY CHECK] ${TOOL_NAME} used ${CONSECUTIVE} consecutive times. Consider reviewing results manually.\"}"
      ;;
  esac
fi

exit 0
