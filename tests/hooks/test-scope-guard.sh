#!/bin/bash
# Tests for scope-guard.sh
# Usage: bash tests/hooks/test-scope-guard.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/scope-guard.sh"
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
export CLAUDE_SESSION_ID="test-scope-$$"
TRACK_DIR="/tmp/claude-scope-test-scope-$$"

cleanup() {
  rm -rf "$TRACK_DIR"
}
trap cleanup EXIT

reset_state() {
  rm -rf "$TRACK_DIR"
}

# --- Non-tracked tools pass through ---

test_ignores_read_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Read"
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/test.txt"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Read tool (not tracked)" "$output"
}

test_ignores_bash_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='{"command":"ls"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Bash tool (not tracked)" "$output"
}

test_ignores_grep_tool() {
  reset_state
  export CLAUDE_TOOL_NAME="Grep"
  export CLAUDE_TOOL_INPUT='{"pattern":"TODO"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Grep tool (not tracked)" "$output"
}

# --- Below threshold (no warning) ---

test_first_write_no_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file1.txt","content":"hello"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "first Write: no warning" "$output"
}

test_edit_below_threshold() {
  reset_state
  export CLAUDE_TOOL_NAME="Edit"
  # Pre-populate with 5 unique files
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 5); do
    echo "/tmp/file${i}.txt" >> "$TRACK_DIR/files.txt"
  done
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file6.txt","old_string":"a","new_string":"b"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "6 files: no warning (below 10)" "$output"
}

# --- Soft warning at 10 files ---

test_warns_at_10_files() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  # Pre-populate with 9 unique files
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 9); do
    echo "/tmp/file${i}.txt" >> "$TRACK_DIR/files.txt"
  done
  # The 10th file triggers soft warning
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file10.txt","content":"hello"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "10 files: soft warning" "SCOPE GUARD" "$output"
  assert_output_contains "10 files: additionalContext" "additionalContext" "$output"
}

# --- Hard warning at 20 files ---

test_asks_at_20_files() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  # Pre-populate with 19 unique files
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 19); do
    echo "/tmp/file${i}.txt" >> "$TRACK_DIR/files.txt"
  done
  # The 20th file triggers hard warning
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file20.txt","content":"hello"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "20 files: hard warning" "SCOPE GUARD" "$output"
  assert_output_contains "20 files: decision ask" "decision" "$output"
}

# --- Duplicate files not double-counted ---

test_duplicate_files_not_counted() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 9); do
    echo "/tmp/file${i}.txt" >> "$TRACK_DIR/files.txt"
  done
  # Write to an already-tracked file (file1) — should not increment count
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file1.txt","content":"updated"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "duplicate file: no warning (still 9)" "$output"
}

# --- Empty/missing file_path ---

test_empty_tool_input() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT=""
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "empty input: no warning" "$output"
}

test_no_file_path_in_input() {
  reset_state
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"old_string":"a","new_string":"b"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "no file_path: no warning" "$output"
}

# --- Path traversal rejected ---

test_rejects_path_traversal() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"../../etc/passwd","content":"evil"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "path traversal: silently rejected" "$output"
  # Verify the path was NOT added to tracking
  if [ -f "$TRACK_DIR/files.txt" ]; then
    count=$(wc -l < "$TRACK_DIR/files.txt" | tr -d ' ')
    if [ "$count" -eq 0 ]; then
      echo "  PASS path traversal: not tracked"
      ((PASS++))
    else
      echo "  FAIL path traversal: was tracked ($count entries)"
      ((FAIL++))
    fi
  else
    echo "  PASS path traversal: no tracking file created"
    ((PASS++))
  fi
}

# --- Always exits 0 ---

test_exits_zero_on_warning() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  mkdir -p "$TRACK_DIR"
  for i in $(seq 1 25); do
    echo "/tmp/file${i}.txt" >> "$TRACK_DIR/files.txt"
  done
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/file26.txt","content":"hello"}'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 even on hard warning" 0 $?
}

test_exits_zero_clean() {
  reset_state
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/test.txt","content":"hello"}'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 on clean input" 0 $?
}

# Run all tests
echo "=== scope-guard.sh ==="
test_ignores_read_tool
test_ignores_bash_tool
test_ignores_grep_tool
test_first_write_no_warning
test_edit_below_threshold
test_warns_at_10_files
test_asks_at_20_files
test_duplicate_files_not_counted
test_empty_tool_input
test_no_file_path_in_input
test_rejects_path_traversal
test_exits_zero_on_warning
test_exits_zero_clean

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
