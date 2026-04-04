#!/bin/bash
# Circuit Breaker Reset — clears failure count on successful tool use
# Counterpart to circuit-breaker.sh
# Used by PostToolUse hook

STATE_FILE="/tmp/claude-circuit-breaker-${CLAUDE_SESSION_ID:-shared}"
[ -f "$STATE_FILE" ] && echo "0" > "$STATE_FILE"
exit 0
