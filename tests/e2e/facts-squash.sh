#!/usr/bin/env bash
# GitHub squash 的真实语义：任务分支 tip 不在 main 历史上。
# #38 的契约把「已合入」写成了 git 祖先检查，夹具用 merge 进 main 的 tip 绿了，这里会红。
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
. "$ROOT/lib/parse.sh"
# shellcheck source=/dev/null
. "$ROOT/lib/github.sh"
# shellcheck source=/dev/null
. "$ROOT/tests/e2e/lib.sh"

trap e2e_cleanup EXIT
e2e_setup

br="$(e2e_name squash)"
e2e_push_branch "$E2E_TMP/wt" "$br" "e2e-runs/${br}/note.txt"
read -r pr_num tip merge_oid <<<"$(e2e_pr_squash_keep_branch "$br" "e2e squash ${br}")"

head_oid="$(GH_PAGER=cat gh pr view "$pr_num" --repo "$SANDBOX_REPO" --json headRefOid -q .headRefOid)"
state="$(GH_PAGER=cat gh pr view "$pr_num" --repo "$SANDBOX_REPO" --json state -q .state)"

e2e_expect_eq "squash 后 PR MERGED" MERGED "$state"
e2e_expect_eq "headRefOid 等于合入前 tip" "$tip" "$head_oid"
e2e_expect_true "mergeCommit 非空" '[ -n "$merge_oid" ]'
e2e_expect_true "mergeCommit 是 origin/e2e/base 祖先" \
  'git -C "$E2E_TMP/wt" merge-base --is-ancestor "$merge_oid" "origin/${SANDBOX_MAIN}"'
e2e_expect_true "tip 不是 origin/e2e/base 祖先（GitHub squash 事实）" \
  '! git -C "$E2E_TMP/wt" merge-base --is-ancestor "$tip" "origin/${SANDBOX_MAIN}"'
e2e_expect_true "远端任务分支仍在" \
  'git -C "$E2E_TMP/wt" ls-remote --exit-code origin "refs/heads/${br}" >/dev/null'

echo
echo "事实：squash 之后 tip=${tip:0:12} 不在 e2e/base 历史上，mergeCommit=${merge_oid:0:12} 在。"
echo "只认 merge-base --is-ancestor 的 finalize 会在这里拒绝删分支。"
e2e_finish
