#!/usr/bin/env bash
# Test suite for simplify-ignore.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/simplify-ignore.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export CLAUDE_PLUGIN_ROOT="$TMP_DIR"
mkdir -p "$TMP_DIR/.claude/.simplify-ignore-cache"

pass=0
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    ((pass++))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((fail++))
  fi
}

# Test 1: protect + restore round-trip
echo "Test 1: Round-trip protect/restore"
cat > "$TMP_DIR/test1.kt" <<'EOF'
fun normalCode() {
    println("hello")
}
/* simplify-ignore-start */
fun protectedCode() {
    // This should not be simplified
    val x = computeExpensiveValue()
}
/* simplify-ignore-end */
fun moreCode() {
    println("world")
}
EOF
ORIGINAL=$(cat "$TMP_DIR/test1.kt")
bash "$SCRIPT" protect "$TMP_DIR/test1.kt" >/dev/null
PROTECTED=$(cat "$TMP_DIR/test1.kt")
assert_eq "Protected file differs from original" "true" "$( [[ "$PROTECTED" != "$ORIGINAL" ]] && echo true || echo false )"
assert_eq "Protected file contains placeholder" "true" "$( grep -q 'BLOCK_' "$TMP_DIR/test1.kt" && echo true || echo false )"

bash "$SCRIPT" restore "$TMP_DIR/test1.kt" >/dev/null
RESTORED=$(cat "$TMP_DIR/test1.kt")
assert_eq "Restored file matches original" "$ORIGINAL" "$RESTORED"

# Test 2: file with no annotations
echo "Test 2: File with no annotations"
cat > "$TMP_DIR/test2.kt" <<'EOF'
fun simpleCode() {
    println("no annotations here")
}
EOF
ORIGINAL2=$(cat "$TMP_DIR/test2.kt")
bash "$SCRIPT" protect "$TMP_DIR/test2.kt" >/dev/null 2>&1 || true
assert_eq "Unannotated file unchanged" "$ORIGINAL2" "$(cat "$TMP_DIR/test2.kt")"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
