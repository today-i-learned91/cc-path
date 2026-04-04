#!/bin/bash
# Integration tests for decision-audit.sh per-tool rolling window
# Tests the NEW counter-file approach that replaced the old tail-5 method.
# Verifies that consecutive same-tool mutation usage triggers AI DEPENDENCY
# warnings, and that interleaving different tools resets the counter.
# Usage: bash tests/integration/test-decision-audit-rolling.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/decision-audit.sh"
PASS=0
FAIL=0

# Isolated session per test run
export CLAUDE_SESSION_ID="integ-rolling-$$"
LOG_DIR="/tmp/claude-audit-integ-rolling-$$"

cleanup() {
  rm -rf "$LOG_DIR"
  unset CLAUDE_TOOL_NAME CLAUDE_TOOL_INPUT CLAUDE_SESSION_ID
}
trap cleanup EXIT

reset_session() {
  rm -rf "$LOG_DIR"
}

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

# --- 3 consecutive Edit calls triggers warning ---

test_3_consecutive_edit_triggers() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1   # 1st Edit
  bash "$HOOK" > /dev/null 2>&1   # 2nd Edit
  output=$(bash "$HOOK" 2>&1)     # 3rd Edit — should trigger
  assert_output_contains "3 consecutive Edit calls triggers AI DEPENDENCY" "AI DEPENDENCY" "$output"
}

# --- 2 Edit then 1 Bash: no warning (different tool resets) ---

test_2_edit_then_bash_no_warning() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1   # 1st Edit
  bash "$HOOK" > /dev/null 2>&1   # 2nd Edit
  export CLAUDE_TOOL_NAME="Bash"
  output=$(bash "$HOOK" 2>&1)     # 1st Bash — should NOT trigger
  assert_output_empty "2 Edit then 1 Bash: no warning (counter reset)" "$output"
}

# --- Interleaved Edit/Bash/Edit/Bash/Edit: no warning ---

test_interleaved_no_warning() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1   # 1st Edit
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1   # 1st Bash
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1   # 2nd Edit
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1   # 2nd Bash
  export CLAUDE_TOOL_NAME="Edit"
  output=$(bash "$HOOK" 2>&1)     # 3rd Edit — but never 3 consecutive
  assert_output_empty "interleaved Edit/Bash never reaches 3 consecutive" "$output"
}

# --- 3 consecutive Read calls: no warning (not a mutation tool) ---

test_3_read_no_warning() {
  reset_session
  export CLAUDE_TOOL_NAME="Read"
  bash "$HOOK" > /dev/null 2>&1   # 1st Read
  bash "$HOOK" > /dev/null 2>&1   # 2nd Read
  output=$(bash "$HOOK" 2>&1)     # 3rd Read — Read is not mutation
  assert_output_empty "3 consecutive Read calls: no warning (not mutation)" "$output"
}

# --- 4 consecutive Write calls: warning with correct count ---

test_4_consecutive_write_count() {
  reset_session
  export CLAUDE_TOOL_NAME="Write"
  bash "$HOOK" > /dev/null 2>&1   # 1st Write
  bash "$HOOK" > /dev/null 2>&1   # 2nd Write
  bash "$HOOK" > /dev/null 2>&1   # 3rd Write (triggers with count 3)
  output=$(bash "$HOOK" 2>&1)     # 4th Write — should show count 4
  assert_output_contains "4 consecutive Write calls shows count 4" "4 consecutive" "$output"
}

# --- Single tool call: no warning ---

test_single_call_no_warning() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  output=$(bash "$HOOK" 2>&1)     # 1st and only call
  assert_output_empty "single Edit call: no warning" "$output"
}

# --- Counter persists across invocations in same session ---

test_counter_persists() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1   # 1st Edit
  bash "$HOOK" > /dev/null 2>&1   # 2nd Edit
  # Verify counter file exists and has value 2
  COUNTER_FILE="$LOG_DIR/.counter_Edit"
  if [ -f "$COUNTER_FILE" ]; then
    count=$(cat "$COUNTER_FILE")
    if [ "$count" -eq 2 ]; then
      echo "  PASS counter persists across invocations (value=2)"
      ((PASS++))
    else
      echo "  FAIL counter persists: expected 2, got $count"
      ((FAIL++))
    fi
  else
    echo "  FAIL counter file not found at $COUNTER_FILE"
    ((FAIL++))
  fi
}

# --- Hook always exits 0 ---

test_exits_zero() {
  reset_session
  export CLAUDE_TOOL_NAME="Edit"
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "decision-audit exits 0 even on AI DEPENDENCY warning" 0 $?
}

# Run all tests
echo "=== decision-audit.sh (rolling window integration) ==="
test_3_consecutive_edit_triggers
test_2_edit_then_bash_no_warning
test_interleaved_no_warning
test_3_read_no_warning
test_4_consecutive_write_count
test_single_call_no_warning
test_counter_persists
test_exits_zero

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
