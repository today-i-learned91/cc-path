#!/bin/bash
# Tests for decision-audit.sh
# Usage: bash tests/hooks/test-decision-audit.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/harness/.claude/hooks/decision-audit.sh"
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
    echo "  FAIL $test_name (pattern '$pattern' not found in: $output)"
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

# Use isolated log dir per test run
export CLAUDE_SESSION_ID="test-audit-$$"
LOG_DIR="/tmp/claude-audit-test-audit-$$"

cleanup() {
  rm -rf "$LOG_DIR"
}
trap cleanup EXIT

reset_log() {
  rm -rf "$LOG_DIR"
}

# --- Basic logging ---

test_exits_zero() {
  reset_log
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "decision-audit always exits 0" 0 $?
}

test_creates_log_file() {
  reset_log
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  LOG_FILE="$LOG_DIR/decisions.jsonl"
  if [ -f "$LOG_FILE" ]; then
    echo "  PASS creates log file at expected path"
    ((PASS++))
  else
    echo "  FAIL log file not created at $LOG_FILE"
    ((FAIL++))
  fi
}

test_log_entry_has_tool_name() {
  reset_log
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1
  LOG_FILE="$LOG_DIR/decisions.jsonl"
  if grep -q '"tool":"Edit"' "$LOG_FILE" 2>/dev/null; then
    echo "  PASS log entry contains tool name"
    ((PASS++))
  else
    echo "  FAIL log entry missing tool name"
    ((FAIL++))
  fi
}

test_log_entry_has_timestamp() {
  reset_log
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  LOG_FILE="$LOG_DIR/decisions.jsonl"
  if grep -q '"ts":' "$LOG_FILE" 2>/dev/null; then
    echo "  PASS log entry contains timestamp"
    ((PASS++))
  else
    echo "  FAIL log entry missing timestamp"
    ((FAIL++))
  fi
}

test_log_entry_has_session() {
  reset_log
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  LOG_FILE="$LOG_DIR/decisions.jsonl"
  if grep -q '"session":"test-audit-' "$LOG_FILE" 2>/dev/null; then
    echo "  PASS log entry contains session id"
    ((PASS++))
  else
    echo "  FAIL log entry missing session id"
    ((FAIL++))
  fi
}

test_appends_multiple_entries() {
  reset_log
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  LOG_FILE="$LOG_DIR/decisions.jsonl"
  line_count=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')
  if [ "$line_count" -ge 3 ]; then
    echo "  PASS log appends multiple entries ($line_count lines)"
    ((PASS++))
  else
    echo "  FAIL log should have 3+ lines, got $line_count"
    ((FAIL++))
  fi
}

# --- AI Dependency Check (3+ consecutive same mutation tool uses) ---

test_no_warning_below_threshold() {
  reset_log
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  output=$(bash "$HOOK" 2>&1)  # 3rd call — threshold is >=3
  # 3rd call on Edit should trigger warning
  assert_output_contains "3rd consecutive Edit triggers AI dependency check" "AI DEPENDENCY" "$output"
}

test_warning_only_for_mutation_tools() {
  reset_log
  export CLAUDE_TOOL_NAME="Read"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  output=$(bash "$HOOK" 2>&1)  # 3rd Read call — Read is not a mutation tool
  assert_output_empty "no warning for 3 consecutive Read calls (not mutation)" "$output"
}

test_warning_for_write_tool() {
  reset_log
  export CLAUDE_TOOL_NAME="Write"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "3rd consecutive Write triggers AI dependency check" "AI DEPENDENCY" "$output"
}

test_warning_for_notebookedit_tool() {
  reset_log
  export CLAUDE_TOOL_NAME="NotebookEdit"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "3rd consecutive NotebookEdit triggers AI dependency check" "AI DEPENDENCY" "$output"
}

# Run all tests
echo "=== decision-audit.sh ==="
test_exits_zero
test_creates_log_file
test_log_entry_has_tool_name
test_log_entry_has_timestamp
test_log_entry_has_session
test_appends_multiple_entries
test_no_warning_below_threshold
test_warning_only_for_mutation_tools
test_warning_for_write_tool
test_warning_for_notebookedit_tool

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
