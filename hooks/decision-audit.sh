#!/bin/bash
# Decision Audit Trail — logs tool usage for transparency
# PostToolUse hook: appends structured entries to session log
# Enables AI Dependency Check from cognitive-protection.md

LOG_DIR="/tmp/claude-audit-${CLAUDE_SESSION_ID:-shared}"
LOG_FILE="${LOG_DIR}/decisions.jsonl"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"

# Append entry
echo "{\"ts\":\"${TIMESTAMP}\",\"tool\":\"${TOOL_NAME}\",\"session\":\"${CLAUDE_SESSION_ID:-shared}\"}" >> "$LOG_FILE"

# --- AI Dependency Check: same tool 3+ times without user interaction ---
if [ -f "$LOG_FILE" ]; then
  # Count consecutive same-tool uses (last N entries)
  RECENT_COUNT=$(tail -5 "$LOG_FILE" | grep -c "\"tool\":\"${TOOL_NAME}\"" 2>/dev/null || echo 0)

  if [ "$RECENT_COUNT" -ge 3 ]; then
    # Check if it's a mutation tool (not reads)
    case "$TOOL_NAME" in
      Edit|Write|Bash|NotebookEdit)
        echo "{\"additionalContext\":\"[AI DEPENDENCY CHECK] ${TOOL_NAME}consecutive uses of ${RECENT_COUNT}. Review results manually?\"}"
        ;;
    esac
  fi
fi

exit 0
