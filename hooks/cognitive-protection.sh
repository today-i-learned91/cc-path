#!/bin/bash
# Cognitive Protection — Escalation Triggers (Hard Confirm)
# Implements cognitive-protection.md escalation rules as a PreToolUse hook
# Matches: Bash, Edit, Write
#
# Checks for sensitive patterns that require explicit user confirmation:
# 1. Auth/payments/PII operations
# 2. Batch operations (10+ files)
# 3. Deploy-guard overlap patterns

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Only check mutation tools
case "$TOOL_NAME" in
  Bash|Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# --- Escalation Trigger 1: Auth, Payments, PII patterns ---
SENSITIVE_PATTERNS="(password|secret|token|api.?key|credential|auth|payment|billing|credit.?card|ssn|social.?security|pii|personal.?data|encrypt|decrypt|private.?key|\.env[^.])"

if echo "$TOOL_INPUT" | grep -qiE "$SENSITIVE_PATTERNS" 2>/dev/null; then
  # Allow reads (grep/cat) but block writes
  if [ "$TOOL_NAME" = "Bash" ]; then
    # Check if ALL segments of the command pipeline are read-only.
    # Split on &&, ||, ;, | and verify each segment independently.
    # A command like "cat file && rm -rf /" must NOT bypass.
    is_read_only_pipeline() {
      local cmd="$1"
      # Reject command substitution and process substitution (Critical: bypass via subshells)
      if echo "$cmd" | grep -qE '(\$\(|`|<\(|>\()' 2>/dev/null; then
        return 1
      fi
      # Reject output redirection (High: file writes via > or >>)
      if echo "$cmd" | grep -qE '[^-]>|^>|>>' 2>/dev/null; then
        return 1
      fi
      local parts
      parts=$(echo "$cmd" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g; s/|/\n/g')
      while IFS= read -r part; do
        # Trim leading/trailing whitespace
        part=$(echo "$part" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -z "$part" ] && continue
        # Check if this segment starts with a known read-only command
        # Note: echo removed from allowlist (High: enables writes with redirection/subshells)
        if ! echo "$part" | grep -qE "^(grep|rg|cat|head|tail|less|find|ls|wc|file|stat|du|df|which|type|whereis|git (log|show|diff|status|branch|remote|tag))" 2>/dev/null; then
          return 1  # NOT read-only
        fi
      done <<< "$parts"
      return 0  # all parts are read-only
    }

    if is_read_only_pipeline "$TOOL_INPUT"; then
      exit 0
    fi
  fi
  echo '{"decision":"ask","reason":"[COGNITIVE PROTECTION] Sensitive data operation detected (auth/payment/PII). Proceed?"}'
  exit 0
fi

# --- Escalation Trigger 2: Destructive patterns (deploy-guard overlap) ---
DESTRUCTIVE_PATTERNS="(rm -rf|DROP TABLE|DROP DATABASE|TRUNCATE|DELETE FROM|--force|--hard|--prod|npm publish|firebase deploy|kubectl delete)"

if echo "$TOOL_INPUT" | grep -qE "$DESTRUCTIVE_PATTERNS" 2>/dev/null; then
  echo '{"decision":"ask","reason":"[COGNITIVE PROTECTION] Destructive operation detected. Proceed?"}'
  exit 0
fi

exit 0
