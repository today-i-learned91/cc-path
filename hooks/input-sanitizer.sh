#!/bin/bash
# Input Sanitizer — Adversarial robustness for MCP/tool inputs
# PreToolUse hook: detects prompt injection patterns in tool inputs
# Aligned with Anthropic's "Fail Closed" principle

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Skip if no input
[ -z "$TOOL_INPUT" ] && exit 0

# --- Pattern 1: System prompt override attempts ---
if echo "$TOOL_INPUT" | grep -qiE "(ignore (all |previous |prior )?instructions|you are now|new system prompt|<system>|</system>|ANTHROPIC_|CLAUDE_SYSTEM)" 2>/dev/null; then
  echo '{"decision":"ask","reason":"[INPUT SANITIZER] Prompt injection pattern detected. Review the input."}'
  exit 0
fi

# --- Pattern 2: Hidden instruction injection via tool results ---
if echo "$TOOL_INPUT" | grep -qiE "(IMPORTANT:|CRITICAL:|OVERRIDE:|YOU MUST|DO NOT FOLLOW)" 2>/dev/null; then
  # Only flag if it's coming from external sources (WebFetch, MCP results)
  case "${CLAUDE_TOOL_NAME:-}" in
    WebFetch|mcp__*)
      echo "{\"additionalContext\":\"[INPUT SANITIZER] Directive pattern detected from external source. Review results critically.\"}"
      ;;
  esac
fi

# --- Pattern 3: Data exfiltration attempts ---
# Build comprehensive exfiltration detection pattern
EXFIL_PATTERNS="("
EXFIL_PATTERNS+="curl.*(\\||--data|--data-binary|-d |-T |-F )"  # curl with data upload or pipe
EXFIL_PATTERNS+="|wget.*(\\||-O[- ]|-q.*-O)"                     # wget with pipe or stdout output
EXFIL_PATTERNS+="|python3? -c.*(urllib|requests|socket|http)"     # python network modules
EXFIL_PATTERNS+="|ruby -e.*(net/http|open-uri|socket)"            # ruby network modules
EXFIL_PATTERNS+="|perl -e.*(IO::Socket|LWP|HTTP)"                 # perl network modules
EXFIL_PATTERNS+="|(nc|ncat|socat) .*[0-9]"                        # netcat variants with addresses
EXFIL_PATTERNS+="|base64.*(\\||<)"                                 # base64 encoding with pipe or redirect
EXFIL_PATTERNS+="|openssl.*(base64|enc)"                           # openssl encoding
EXFIL_PATTERNS+="|/dev/(tcp|udp)/"                                 # bash network redirects
EXFIL_PATTERNS+="|xxd.*\\|.*(nc|curl|wget)"                       # hex encode piped to network
EXFIL_PATTERNS+="|(dig|nslookup) .*\\$"                           # DNS exfiltration with encoded data
EXFIL_PATTERNS+="|(base64 -d|base64 --decode).*\\|.*(sh|bash|zsh|exec)"  # decode-and-execute
EXFIL_PATTERNS+="|rsync.*@"                                        # rsync to remote
EXFIL_PATTERNS+="|scp .*@"                                         # scp to remote
EXFIL_PATTERNS+="|ssh .*<"                                         # ssh with stdin redirect
EXFIL_PATTERNS+="|tftp "                                           # tftp upload
EXFIL_PATTERNS+=")"

if echo "$TOOL_INPUT" | grep -qiE "$EXFIL_PATTERNS" 2>/dev/null; then
  echo '{"decision":"ask","reason":"[INPUT SANITIZER] Data exfiltration pattern detected. Confirmation required."}'
  exit 0
fi

exit 0
