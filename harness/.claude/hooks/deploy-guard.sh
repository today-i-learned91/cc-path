#!/bin/bash
# Deploy Guard — blocks production deployments without explicit confirmation
# Used by PreToolUse hook on Bash matcher
# Exit 0 = allow, Exit 2 = block

COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Production deployment patterns
PROD_PATTERNS=(
  'vercel --prod'
  'vercel.*--prod'
  'firebase deploy'
  '--force'
  'git push.*--force'
  'git push.*-f '
  'npm publish'
  'supabase db push'
)

for pattern in "${PROD_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"프로덕션 배포 명령이 감지되었습니다. 명시적 확인 후 수동 실행하세요."}}' >&2
    exit 2
  fi
done

exit 0
