#!/bin/bash
# Scope Guard — warns when changes exceed file threshold
# PreToolUse hook: tracks unique files modified per session
# Aligned with cognitive-protection.md escalation triggers

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Only check mutation tools
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

TRACK_DIR="/tmp/claude-scope-${CLAUDE_SESSION_ID:-shared}"
TRACK_FILE="${TRACK_DIR}/files.txt"

mkdir -p "$TRACK_DIR"

# Extract file_path from JSON input
# Handles both "file_path":"value" and "file_path": "value"
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Skip if no file path extracted
[ -z "$FILE_PATH" ] && exit 0

# Sanitize: reject paths with traversal patterns or null bytes
if echo "$FILE_PATH" | grep -qE '(\.\./|\.\.\\|%2e%2e)' 2>/dev/null; then
  exit 0
fi

# Create tracking file if it doesn't exist
touch "$TRACK_FILE"

# Add file path if not already tracked (unique entries only)
if ! grep -qxF "$FILE_PATH" "$TRACK_FILE" 2>/dev/null; then
  echo "$FILE_PATH" >> "$TRACK_FILE"
fi

# Count unique files
FILE_COUNT=$(wc -l < "$TRACK_FILE" | tr -d ' ')

# Check thresholds (higher threshold first for correct priority)
if [ "$FILE_COUNT" -ge 20 ]; then
  echo "{\"decision\":\"ask\",\"reason\":\"[SCOPE GUARD] ${FILE_COUNT} files modified this session. This is a large change set. Continue?\"}"
elif [ "$FILE_COUNT" -ge 10 ]; then
  echo "{\"additionalContext\":\"[SCOPE GUARD] ${FILE_COUNT} files modified this session. Consider reviewing changes.\"}"
fi

exit 0
