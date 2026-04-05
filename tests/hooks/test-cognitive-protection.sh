#!/bin/bash
# Tests for cognitive-protection.sh
# Usage: bash tests/hooks/test-cognitive-protection.sh

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

# --- Sensitive patterns flagged on Bash write commands ---

test_flags_password_in_bash() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='echo "password=secret" > config.sh'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: password in Bash" "COGNITIVE PROTECTION" "$output"
}

test_flags_token_in_edit() {
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.ts","old_string":"","new_string":"const token = process.env.TOKEN"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: token in Edit" "COGNITIVE PROTECTION" "$output"
}

test_flags_api_key_in_write() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.json","content":"{\"api_key\":\"abc123\"}"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: api_key in Write" "COGNITIVE PROTECTION" "$output"
}

test_flags_drop_table_in_bash() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='psql -c "DROP TABLE users"'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: DROP TABLE in Bash" "COGNITIVE PROTECTION" "$output"
}

test_flags_rm_rf() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='rm -rf /tmp/build'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: rm -rf in Bash" "COGNITIVE PROTECTION" "$output"
}

test_flags_firebase_deploy() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='firebase deploy --project prod'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: firebase deploy in Bash" "COGNITIVE PROTECTION" "$output"
}

# --- Read-only commands allowed even with sensitive terms ---

test_allows_grep_for_token() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='grep -r "token" src/'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: grep for 'token' (read-only)" "$output"
}

test_allows_git_log_with_auth() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='git log --oneline -- src/auth.ts'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: git log (read-only)" "$output"
}

test_allows_cat_env_example() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='cat .env.example'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: cat .env.example (read-only)" "$output"
}

# --- Non-mutation tools pass through ---

test_allows_read_tool() {
  export CLAUDE_TOOL_NAME="Read"
  export CLAUDE_TOOL_INPUT='{"file_path":"/etc/password"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: Read tool (not a mutation tool)" "$output"
}

test_allows_grep_tool() {
  export CLAUDE_TOOL_NAME="Grep"
  export CLAUDE_TOOL_INPUT='{"pattern":"DROP TABLE","path":"."}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: Grep tool (not a mutation tool)" "$output"
}

# --- Normal mutation operations pass ---

test_allows_normal_edit() {
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"file_path":"README.md","old_string":"old text","new_string":"new text"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: normal Edit (no sensitive patterns)" "$output"
}

test_allows_normal_bash() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='npm run build'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: normal Bash command" "$output"
}

# --- Hook always exits 0 (uses decision:ask, not blocking) ---

test_exits_zero_on_flag() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='rm -rf dist'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "cognitive-protection exits 0 (ask, not block)" 0 $?
}

# Run all tests
echo "=== cognitive-protection.sh ==="
test_flags_password_in_bash
test_flags_token_in_edit
test_flags_api_key_in_write
test_flags_drop_table_in_bash
test_flags_rm_rf
test_flags_firebase_deploy
test_allows_grep_for_token
test_allows_git_log_with_auth
test_allows_cat_env_example
test_allows_read_tool
test_allows_grep_tool
test_allows_normal_edit
test_allows_normal_bash
test_exits_zero_on_flag

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
