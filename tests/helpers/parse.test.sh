#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/lib/parse.sh"

fail=0
pass=0
ok() { pass=$((pass+1)); }
bad() { echo "✗ $*" >&2; fail=$((fail+1)); }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1: 期望 [$2] 实际 [$3]"; fi; }

body40='<!-- task-contract:v1 -->

## 分支建议

- 分支：`meta/zmerge-squash-tip-in-main`
- sparse：`.agents/skills/zmerge`
'
eq "40 分支" "meta/zmerge-squash-tip-in-main" "$(issue_suggested_branch "$body40")"
eq "40 sparse" ".agents/skills/zmerge" "$(issue_suggested_sparse "$body40")"

body_plain='- 分支:meta/drop-contract-v1-protocol
- sparse: `.agents` `0-meta`
'
eq "无反引号分支" "meta/drop-contract-v1-protocol" "$(issue_suggested_branch "$body_plain")"

eq "wt 名" "meta-zmerge-squash-tip-in-main-40" "$(worktree_name 40 meta/zmerge-squash-tip-in-main)"
eq "空分支 wt 名" "issue-33" "$(worktree_name 33 "")"

if branch_ok main; then bad "main 应拒绝"; else ok; fi
if branch_ok 'meta/zmerge-squash-tip-in-main'; then ok; else bad "合法分支被拒"; fi
if issue_number_ok 40; then ok; else bad "40 应合法"; fi
if issue_number_ok 0; then bad "0 应拒绝"; else ok; fi

labels=$'meta\nhuman-merge'
if issue_has_human_merge "$labels"; then ok; else bad "human-merge 未识别"; fi
if issue_has_human_merge $'meta'; then bad "无标签误报"; else ok; fi

echo "helpers ${pass} pass, ${fail} fail"
[ "$fail" = 0 ]
