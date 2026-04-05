#!/bin/bash
# Secret Scanner — detects hardcoded secrets before commit
# PreToolUse hook: scans Write/Edit inputs for secret patterns
# Aligned with "Fail Closed, Default Safe" principle

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Only check Write and Edit tools
case "$TOOL_NAME" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

# Skip if no input
[ -z "$TOOL_INPUT" ] && exit 0

# --- False positive exclusions ---
# Skip .env.example files
if echo "$TOOL_INPUT" | grep -q '\.env\.example' 2>/dev/null; then
  exit 0
fi

# Helper: check if match is a placeholder value
is_placeholder() {
  local input="$1"
  if echo "$input" | grep -qiE '(your-api-key-here|your[-_]?key[-_]?here|xxx+|TODO|CHANGEME|REPLACE[-_]?ME|placeholder|example|fake[-_]?key|test[-_]?key|sk-\.\.\.|\.\.\.)' 2>/dev/null; then
    return 0
  fi
  return 1
}

# Check for placeholder values first — skip if entire input looks like a template
if is_placeholder "$TOOL_INPUT"; then
  exit 0
fi

# --- Pattern 1: API keys (sk-, pk-, ak- prefixed or api_key assignments) ---
if echo "$TOOL_INPUT" | grep -qE '(sk-|pk-|ak-)[a-zA-Z0-9]{20,}' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (API key prefix). Use .env instead?"}'
  exit 0
fi
if echo "$TOOL_INPUT" | grep -qiE 'api[_-]?key\s*[:=]\s*["'"'"'][a-zA-Z0-9]{20,}' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (API key assignment). Use .env instead?"}'
  exit 0
fi

# --- Pattern 2: AWS credentials ---
if echo "$TOOL_INPUT" | grep -qE 'AKIA[0-9A-Z]{16}' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (AWS access key). Use .env instead?"}'
  exit 0
fi
if echo "$TOOL_INPUT" | grep -qiE 'aws[_-]?secret[_-]?access[_-]?key' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (AWS secret key). Use .env instead?"}'
  exit 0
fi

# --- Pattern 3: GitHub tokens ---
if echo "$TOOL_INPUT" | grep -qE '(ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59})' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (GitHub token). Use .env instead?"}'
  exit 0
fi

# --- Pattern 4: Generic secret assignments ---
if echo "$TOOL_INPUT" | grep -qiE '(password|secret|token|credential)\s*[:=]\s*["'"'"'][^"'"'"']{8,}["'"'"']' 2>/dev/null; then
  # Recheck: exclude placeholders in the matched value
  MATCH=$(echo "$TOOL_INPUT" | grep -oiE '(password|secret|token|credential)\s*[:=]\s*["'"'"'][^"'"'"']{8,}["'"'"']' 2>/dev/null | head -1)
  if ! is_placeholder "$MATCH"; then
    echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (secret assignment). Use .env instead?"}'
    exit 0
  fi
fi

# --- Pattern 5: Private keys ---
if echo "$TOOL_INPUT" | grep -qE '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (private key). Use .env instead?"}'
  exit 0
fi

# --- Pattern 6: Connection strings with credentials ---
if echo "$TOOL_INPUT" | grep -qE '(mongodb|postgres|mysql|redis)://[^\s]+@' 2>/dev/null; then
  echo '{"decision":"ask","reason":"[SECRET SCANNER] Possible hardcoded secret detected (connection string). Use .env instead?"}'
  exit 0
fi

exit 0
