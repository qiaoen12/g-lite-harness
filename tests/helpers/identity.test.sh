#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/identity.sh
SUT_REPO=evil/other
SUT_MAIN=develop
SANDBOX_REPO=evil/other
SANDBOX_MAIN=develop
E2E_BRANCH_PREFIX=tmp/
HARNESS_SUT_REPO=evil/other
HARNESS_SANDBOX_REPO=evil/other
. "$ROOT/tests/lib/identity.sh"

fail=0
pass=0
ok() { pass=$((pass + 1)); }
bad() { echo "✗ $*" >&2; fail=$((fail + 1)); }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1: 期望 [$2] 实际 [$3]"; fi; }

eq "HARNESS_SUT_REPO 不可覆盖" qiaoen12/g-lite "$HARNESS_SUT_REPO"
eq "HARNESS_SUT_MAIN 不可覆盖" main "$HARNESS_SUT_MAIN"
eq "HARNESS_SANDBOX_REPO 不可覆盖" qiaoen12/g-lite-harness "$HARNESS_SANDBOX_REPO"
eq "HARNESS_SANDBOX_MAIN 不可覆盖" e2e/base "$HARNESS_SANDBOX_MAIN"
eq "E2E 前缀不可覆盖" e2e/ "$HARNESS_E2E_PREFIX"
eq "兼容 SANDBOX_REPO" qiaoen12/g-lite-harness "$SANDBOX_REPO"
if grep -q G_LITE_QUEUE "$ROOT/tests/lib/identity.sh"; then
  bad "identity.sh 不应读取任务队列"
else
  ok
fi

echo "identity ${pass} pass, ${fail} fail"
[ "$fail" = 0 ]
