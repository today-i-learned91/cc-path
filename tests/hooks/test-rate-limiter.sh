#!/bin/bash
# Tests for rate-limiter.sh
# Usage: bash tests/hooks/test-rate-limiter.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/rate-limiter.sh"
PASS=0
FAIL=0

assert_exit() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  PASS $test_name"
    ((PASS++))
  else
    echo "  FAIL $test_name (expected exit $expected, got $actual)"
    ((FAIL++))
  fi
}

assert_output_contains() {
  local test_name="$1"
  local pattern="$2"
  local output="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS $test_name"
    ((PASS++))
  else
    echo "  FAIL $test_name (pattern '$pattern' not in output: $output)"
    ((FAIL++))
  fi
}

assert_output_empty() {
  local test_name="$1"
  local output="$2"
  if [ -z "$output" ]; then
    echo "  PASS $test_name"
    ((PASS++))
  else
    echo "  FAIL $test_name (expected empty output, got: $output)"
    ((FAIL++))
  fi
}

# Use isolated session per test run
export CLAUDE_SESSION_ID="test-ratelimit-$$"
TRACK_DIR="/tmp/claude-ratelimit-test-ratelimit-$$"

cleanup() {
  rm -rf "$TRACK_DIR"
}
trap cleanup EXIT

reset_state() {
  rm -rf "$TRACK_DIR"
}

# --- Non-tracked tools pass through ---

test_ignores_edit_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"file_path":"test.sh"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Edit tool (not rate-limited)" "$output"
}

test_ignores_read_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Read"
  export CLAUDE_TOOL_INPUT='{"file_path":"test.sh"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Read tool (not rate-limited)" "$output"
}

test_ignores_bash_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='{"command":"ls"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Bash tool (not rate-limited)" "$output"
}

# --- First call within threshold ---

test_webfetch_first_call_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "WebFetch: first call no warning" "$output"
}

test_websearch_first_call_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="WebSearch"
  export CLAUDE_TOOL_INPUT='{"query":"test"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "WebSearch: first call no warning" "$output"
}

test_mcp_first_call_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="mcp__slack__send_message"
  export CLAUDE_TOOL_INPUT='{"channel":"general"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "mcp__*: first call no warning" "$output"
}

# --- Exceeding threshold triggers warning ---

test_webfetch_exceeds_threshold() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  NOW=$(date +%s)
  # Pre-populate log with 10 entries (at threshold)
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 10); do
    echo "{\"ts\":${NOW},\"tool\":\"WebFetch\"}" >> "$TRACK_DIR/calls.jsonl"
  done
  # The 11th call should trigger
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "WebFetch: warns at 11 calls" "RATE LIMITER" "$output"
}

test_mcp_exceeds_threshold() {
  reset_state
  export CLAUDE_TOOL_NAME="mcp__knowledge__search"
  export CLAUDE_TOOL_INPUT='{"query":"test"}'
  NOW=$(date +%s)
  # Pre-populate log with 20 entries (at threshold)
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 20); do
    echo "{\"ts\":${NOW},\"tool\":\"mcp__knowledge__search\"}" >> "$TRACK_DIR/calls.jsonl"
  done
  # The 21st call should trigger
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "mcp__*: warns at 21 calls" "RATE LIMITER" "$output"
}

# --- Below threshold does not trigger ---

test_webfetch_at_threshold_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  NOW=$(date +%s)
  # Pre-populate with 9 entries (below threshold)
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 9); do
    echo "{\"ts\":${NOW},\"tool\":\"WebFetch\"}" >> "$TRACK_DIR/calls.jsonl"
  done
  # The 10th call — exactly at threshold, not over
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "WebFetch: no warning at exactly 10 calls" "$output"
}

# --- Old entries are cleaned up ---

test_old_entries_ignored() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  OLD_TS=$(($(date +%s) - 120))
  # Pre-populate with 15 entries from 2 minutes ago (outside window)
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 15); do
    echo "{\"ts\":${OLD_TS},\"tool\":\"WebFetch\"}" >> "$TRACK_DIR/calls.jsonl"
  done
  # Current call should be the only recent one
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "old entries outside window ignored" "$output"
}

# --- Always exits 0 ---

test_always_exits_zero_on_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  NOW=$(date +%s)
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 15); do
    echo "{\"ts\":${NOW},\"tool\":\"WebFetch\"}" >> "$TRACK_DIR/calls.jsonl"
  done
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 even when warning" 0 $?
}

test_always_exits_zero_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="WebFetch"
  export CLAUDE_TOOL_INPUT='{"url":"https://example.com"}'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 with no warning" 0 $?
}

# Run all tests
echo "=== rate-limiter.sh ==="
test_ignores_edit_tool
test_ignores_read_tool
test_ignores_bash_tool
test_webfetch_first_call_no_warning
test_websearch_first_call_no_warning
test_mcp_first_call_no_warning
test_webfetch_exceeds_threshold
test_mcp_exceeds_threshold
test_webfetch_at_threshold_no_warning
test_old_entries_ignored
test_always_exits_zero_on_warning
test_always_exits_zero_no_warning

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
