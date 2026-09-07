#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
pass=0
ok() { pass=$((pass+1)); }
bad() { echo "✗ $*" >&2; fail=$((fail+1)); }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1: 期望 [$2] 实际 [$3]"; fi; }

SANDBOX_REPO=evil/other
SANDBOX_MAIN=develop
E2E_BRANCH_PREFIX=tmp/
# shellcheck source=/dev/null
. "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
. "$ROOT/lib/parse.sh"

eq "SANDBOX_REPO 不可覆盖" qiaoen12/ceshi "$SANDBOX_REPO"
eq "SANDBOX_MAIN 不可覆盖" main "$SANDBOX_MAIN"
eq "E2E 前缀不可覆盖" e2e/ "$E2E_BRANCH_PREFIX"

open_hm='{"state":"OPEN","labels":[{"name":"meta"},{"name":"human-merge"}]}'
closed_hm='{"state":"CLOSED","labels":[{"name":"human-merge"}]}'
open_no='{"state":"OPEN","labels":[{"name":"meta"}]}'

if issue_open_human_merge_ok "$open_hm"; then ok; else bad "OPEN+human-merge 应通过"; fi
rc=0
issue_open_human_merge_ok "$closed_hm" || rc=$?
eq "CLOSED 返回 1" 1 "$rc"
rc=0
issue_open_human_merge_ok "$open_no" || rc=$?
eq "缺标签返回 2" 2 "$rc"

echo "guard ${pass} pass, ${fail} fail"
[ "$fail" = 0 ]
