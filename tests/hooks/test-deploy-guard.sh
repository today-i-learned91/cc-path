#!/bin/bash
# Tests for deploy-guard.sh
# Usage: bash tests/hooks/test-deploy-guard.sh

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/deploy-guard.sh"
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

# --- Blocked commands (exit 2) ---

test_blocks_git_push_force() {
  export CLAUDE_TOOL_INPUT='{"command":"git push --force"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: git push --force" 2 $?
}

test_blocks_git_push_force_short() {
  export CLAUDE_TOOL_INPUT='{"command":"git push -f origin main"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: git push -f origin main" 2 $?
}

test_blocks_npm_publish() {
  export CLAUDE_TOOL_INPUT='{"command":"npm publish"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: npm publish" 2 $?
}

test_blocks_firebase_deploy() {
  export CLAUDE_TOOL_INPUT='{"command":"firebase deploy"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: firebase deploy" 2 $?
}

test_blocks_vercel_prod() {
  export CLAUDE_TOOL_INPUT='{"command":"vercel --prod"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: vercel --prod" 2 $?
}

test_blocks_supabase_db_push() {
  export CLAUDE_TOOL_INPUT='{"command":"supabase db push"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "blocks: supabase db push" 2 $?
}

# --- Allowed commands (exit 0) ---

test_allows_git_push_no_force() {
  export CLAUDE_TOOL_INPUT='{"command":"git push origin main"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "allows: git push (no --force)" 0 $?
}

test_allows_npm_install() {
  export CLAUDE_TOOL_INPUT='{"command":"npm install"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "allows: npm install" 0 $?
}

test_allows_git_status() {
  export CLAUDE_TOOL_INPUT='{"command":"git status"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "allows: git status" 0 $?
}

test_allows_empty_input() {
  export CLAUDE_TOOL_INPUT='{}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "allows: empty command field" 0 $?
}

test_allows_ls() {
  export CLAUDE_TOOL_INPUT='{"command":"ls -la"}'
  export CLAUDE_TOOL_NAME="Bash"
  bash "$HOOK" > /dev/null 2>&1
  assert_exit "allows: ls -la" 0 $?
}

# --- Output content check ---

test_deny_output_contains_reason() {
  export CLAUDE_TOOL_INPUT='{"command":"npm publish"}'
  export CLAUDE_TOOL_NAME="Bash"
  output=$(bash "$HOOK" 2>&1)
  if echo "$output" | grep -q "permissionDecision"; then
    echo "  PASS deny output contains permissionDecision"
    ((PASS++))
  else
    echo "  FAIL deny output missing permissionDecision"
    ((FAIL++))
  fi
}

# Run all tests
echo "=== deploy-guard.sh ==="
test_blocks_git_push_force
test_blocks_git_push_force_short
test_blocks_npm_publish
test_blocks_firebase_deploy
test_blocks_vercel_prod
test_blocks_supabase_db_push
test_allows_git_push_no_force
test_allows_npm_install
test_allows_git_status
test_allows_empty_input
test_allows_ls
test_deny_output_contains_reason

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
