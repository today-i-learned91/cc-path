#!/bin/bash
# Tests for circuit-breaker.sh, circuit-breaker-gate.sh, circuit-breaker-reset.sh
# Usage: bash tests/hooks/test-circuit-breaker.sh

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK_FAIL="$ROOT/harness/.claude/hooks/circuit-breaker.sh"
HOOK_GATE="$ROOT/harness/.claude/hooks/circuit-breaker-gate.sh"
HOOK_RESET="$ROOT/harness/.claude/hooks/circuit-breaker-reset.sh"
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
    echo "  FAIL $test_name (expected pattern '$pattern' in output: $output)"
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

# Use isolated state file per test run
export CLAUDE_SESSION_ID="test-$$"
STATE_FILE="/tmp/claude-circuit-breaker-test-$$"

cleanup() {
  rm -f "$STATE_FILE"
}
trap cleanup EXIT

reset_state() {
  rm -f "$STATE_FILE"
}

set_count() {
  echo "$1" > "$STATE_FILE"
}

# --- circuit-breaker.sh (PostToolUseFailure) ---

test_first_failure_no_output() {
  reset_state
  output=$(bash "$HOOK_FAIL" 2>&1)
  assert_output_empty "first failure: no output" "$output"
}

test_second_failure_no_output() {
  reset_state
  bash "$HOOK_FAIL" > /dev/null 2>&1
  output=$(bash "$HOOK_FAIL" 2>&1)
  assert_output_empty "second failure: no output" "$output"
}

test_third_failure_emits_warn() {
  reset_state
  set_count 2
  output=$(bash "$HOOK_FAIL" 2>&1)
  assert_output_contains "3rd failure: warn output" "CIRCUIT BREAKER" "$output"
}

test_fifth_failure_emits_critical() {
  reset_state
  set_count 4
  output=$(bash "$HOOK_FAIL" 2>&1)
  assert_output_contains "5th failure: critical output" "CRITICAL" "$output"
}

test_failure_increments_count() {
  reset_state
  bash "$HOOK_FAIL" > /dev/null 2>&1
  bash "$HOOK_FAIL" > /dev/null 2>&1
  count=$(cat "$STATE_FILE" 2>/dev/null)
  if [ "$count" -eq 2 ]; then
    echo "  PASS failure increments counter to 2"
    ((PASS++))
  else
    echo "  FAIL failure increments counter (expected 2, got $count)"
    ((FAIL++))
  fi
}

test_circuit_breaker_exits_zero() {
  reset_state
  bash "$HOOK_FAIL" > /dev/null 2>&1
  assert_exit "circuit-breaker always exits 0" 0 $?
}

# --- circuit-breaker-gate.sh (PreToolUse) ---

test_gate_allows_below_threshold() {
  reset_state
  set_count 4
  bash "$HOOK_GATE" > /dev/null 2>&1
  assert_exit "gate: allows at count 4 (below 5)" 0 $?
}

test_gate_blocks_at_threshold() {
  reset_state
  set_count 5
  bash "$HOOK_GATE" > /dev/null 2>&1
  assert_exit "gate: blocks at count 5" 2 $?
}

test_gate_blocks_above_threshold() {
  reset_state
  set_count 7
  bash "$HOOK_GATE" > /dev/null 2>&1
  assert_exit "gate: blocks at count 7 (above 5)" 2 $?
}

test_gate_allows_no_state_file() {
  reset_state
  bash "$HOOK_GATE" > /dev/null 2>&1
  assert_exit "gate: allows when no state file" 0 $?
}

# --- circuit-breaker-reset.sh (PostToolUse) ---

test_reset_clears_count() {
  reset_state
  set_count 5
  bash "$HOOK_RESET" > /dev/null 2>&1
  count=$(cat "$STATE_FILE" 2>/dev/null)
  if [ "$count" -eq 0 ]; then
    echo "  PASS reset: clears count to 0"
    ((PASS++))
  else
    echo "  FAIL reset: expected 0, got $count"
    ((FAIL++))
  fi
}

test_reset_exits_zero() {
  reset_state
  bash "$HOOK_RESET" > /dev/null 2>&1
  assert_exit "reset: always exits 0" 0 $?
}

test_reset_no_state_file_ok() {
  reset_state
  bash "$HOOK_RESET" > /dev/null 2>&1
  assert_exit "reset: exits 0 with no state file" 0 $?
}

# Run all tests
echo "=== circuit-breaker.sh / gate / reset ==="
test_first_failure_no_output
test_second_failure_no_output
test_third_failure_emits_warn
test_fifth_failure_emits_critical
test_failure_increments_count
test_circuit_breaker_exits_zero
test_gate_allows_below_threshold
test_gate_blocks_at_threshold
test_gate_blocks_above_threshold
test_gate_allows_no_state_file
test_reset_clears_count
test_reset_exits_zero
test_reset_no_state_file_ok

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
