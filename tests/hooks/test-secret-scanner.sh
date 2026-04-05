#!/bin/bash
# Tests for secret-scanner.sh
# Usage: bash tests/hooks/test-secret-scanner.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/secret-scanner.sh"
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

# --- Non-target tools pass through ---

test_ignores_bash_tool() {
  export CLAUDE_TOOL_NAME="Bash"
  export CLAUDE_TOOL_INPUT='{"command":"echo sk-abcdefghij1234567890abcdefghij"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Bash tool (not scanned)" "$output"
}

test_ignores_read_tool() {
  export CLAUDE_TOOL_NAME="Read"
  export CLAUDE_TOOL_INPUT='{"file_path":"/etc/passwd"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "ignores: Read tool (not scanned)" "$output"
}

# --- Pattern matches (should flag) ---

test_flags_sk_prefix_key() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.js","content":"const key = \"sk-abcdefghij1234567890abcdefghij\""}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: sk- prefixed API key" "SECRET SCANNER" "$output"
}

test_flags_aws_access_key() {
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.py","old_string":"key=old","new_string":"key=AKIAIOSFODNN7EXAMPLE"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: AWS access key (AKIA...)" "SECRET SCANNER" "$output"
}

test_flags_github_pat() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"ci.yml","content":"token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: GitHub personal access token" "SECRET SCANNER" "$output"
}

test_flags_generic_password() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"app.py","content":"password = \"supersecretpassword123\""}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: generic password assignment" "SECRET SCANNER" "$output"
}

test_flags_private_key() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"key.pem","content":"-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAK..."}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: RSA private key" "SECRET SCANNER" "$output"
}

test_flags_connection_string() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"db.py","content":"url = \"postgres://admin:pass123@db.host.com:5432/mydb\""}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: connection string with credentials" "SECRET SCANNER" "$output"
}

test_flags_api_key_assignment() {
  export CLAUDE_TOOL_NAME="Edit"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.ts","old_string":"TODO","new_string":"api_key = \"abcdefghijklmnopqrstuvwxyz1234567890\""}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_contains "flags: api_key assignment" "SECRET SCANNER" "$output"
}

# --- False positives (should NOT flag) ---

test_allows_env_example_file() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":".env.example","content":"API_KEY=sk-your-api-key-here-replace-me-now-xxxx"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: .env.example file" "$output"
}

test_allows_placeholder_values() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"config.js","content":"password = \"your-api-key-here\""}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: placeholder value (your-api-key-here)" "$output"
}

test_allows_normal_code() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"app.js","content":"const greeting = \"hello world\";\nconsole.log(greeting);"}'
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: normal code without secrets" "$output"
}

test_allows_empty_input() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT=""
  output=$(bash "$HOOK" 2>&1)
  assert_output_empty "allows: empty input" "$output"
}

# --- Always exits 0 ---

test_exits_zero_on_detection() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"key.pem","content":"-----BEGIN PRIVATE KEY-----\ndata..."}'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 on detection" 0 $?
}

test_exits_zero_on_clean() {
  export CLAUDE_TOOL_NAME="Write"
  export CLAUDE_TOOL_INPUT='{"file_path":"app.js","content":"const x = 1;"}'
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "always exits 0 on clean input" 0 $?
}

# Run all tests
echo "=== secret-scanner.sh ==="
test_ignores_bash_tool
test_ignores_read_tool
test_flags_sk_prefix_key
test_flags_aws_access_key
test_flags_github_pat
test_flags_generic_password
test_flags_private_key
test_flags_connection_string
test_flags_api_key_assignment
test_allows_env_example_file
test_allows_placeholder_values
test_allows_normal_code
test_allows_empty_input
test_exits_zero_on_detection
test_exits_zero_on_clean

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
