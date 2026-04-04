#!/bin/bash
# Run all hook tests and report results
# Usage: bash tests/run-all.sh
#   from repo root: bash tests/run-all.sh
#   or from tests/: bash run-all.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
ERRORS=()

echo "================================================"
echo " cc-path hook test suite"
echo "================================================"
echo ""

for test_file in "$SCRIPT_DIR"/hooks/test-*.sh; do
  test_name="$(basename "$test_file")"
  if bash "$test_file"; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+=("$test_name")
  fi
  echo ""
done

echo "================================================"
echo " Results: $PASS passed, $FAIL failed"
echo "================================================"

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo ""
  echo "Failed test files:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
fi

[ "$FAIL" -eq 0 ]
