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
    # Check if it's a read-only command
    if echo "$TOOL_INPUT" | grep -qE "^(grep|rg|cat|head|tail|less|find|ls|echo|git log|git show|git diff)" 2>/dev/null; then
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
