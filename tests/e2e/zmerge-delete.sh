#!/usr/bin/env bash
# 真实 GitHub + 生产 zmerge_delete_remote_branch 的集成测试（#40 A1–A3）。
# 不是完整 zmerge_run。代码来自 CESHI_SUT_CODE。
# 当前 main 的祖先检查会让 A1 失败，这就是 #40 要修的。
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

SUT="${CESHI_SUT_CODE:-$SUT_ROOT}"
MERGE_LIB="$SUT/.agents/skills/zmerge/scripts/merge-lib.sh"
CORE="$SUT/0-meta/lib/new/core.sh"
[ -f "$MERGE_LIB" ] || die "找不到 $MERGE_LIB"
[ -f "$CORE" ] || die "找不到 $CORE"

# shellcheck source=/dev/null
. "$CORE"
# shellcheck source=/dev/null
. "$MERGE_LIB"

task_branch_pushable() {
  local br="$1" main="$2"
  [ -n "$br" ] || return 1
  [ "$br" != HEAD ] || return 1
  [ "$br" != "$main" ] || return 1
  [ "$br" != main ] || return 1
  [[ "$br" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]]
}

z_fetch_origin_main() {
  local wt="${1:-$Z_WT}" main="${2:-$Z_MAIN}"
  GIT_TERMINAL_PROMPT=0 git -C "$wt" fetch --quiet origin \
    "refs/heads/${main}:refs/remotes/origin/${main}"
}

setup_z_for() {
  local wt="$1" br="$2"
  Z_WT="$wt"
  Z_MAIN="$SANDBOX_MAIN"
  Z_OWNER="${SANDBOX_REPO%/*}"
  Z_REPO="${SANDBOX_REPO#*/}"
  Z_NUMBER=40
  Z_GIT_BR="$br"
  Z_HEAD="$(git -C "$wt" rev-parse HEAD)"
  METRICS_REASON_CODE=""
}

trap e2e_cleanup EXIT
e2e_setup

# A1：squash 后 tip 不在 main 历史上，但 MERGED PR headRefOid == tip。应删除成功。
br1="$(e2e_name zmerge-a1)"
e2e_push_branch "$E2E_TMP/wt" "$br1" "e2e-runs/${br1}/note.txt"
read -r pr1 tip1 merge1 <<<"$(e2e_pr_squash_keep_branch "$br1" "e2e zmerge A1 ${br1}")"
git -C "$E2E_TMP/wt" checkout -q "$br1"
setup_z_for "$E2E_TMP/wt" "$br1"
a1rc=0
zmerge_delete_remote_branch >"$E2E_TMP/a1.out" 2>"$E2E_TMP/a1.err" || a1rc=$?
if [ "$a1rc" = 0 ]; then
  e2e_ok "40-A1 squash 后删除成功"
  e2e_expect_true "40-A1 porcelain deleted" 'grep -Fq "porcelain=deleted" "$E2E_TMP/a1.out"'
  e2e_expect_true "40-A1 远端已无分支" \
    '! git -C "$E2E_TMP/wt" ls-remote --exit-code origin "refs/heads/${br1}" >/dev/null 2>&1'
  e2e_forget "$br1"
else
  e2e_bad "40-A1 期望删除成功，rc=${a1rc} reason=${METRICS_REASON_CODE:-空}"
  echo "---- a1.err ----" >&2
  cat "$E2E_TMP/a1.err" >&2 || true
  echo "tip=${tip1:0:12} merge=${merge1:0:12} pr=${pr1}" >&2
  echo "当前 zmerge 若只认祖先，会在真实 squash 后走到这里。这是 #40。" >&2
fi

# A2：同样准备后把远端推到新 tip，必须拒绝，新 tip 仍在。
br2="$(e2e_name zmerge-a2)"
e2e_push_branch "$E2E_TMP/wt" "$br2" "e2e-runs/${br2}/note.txt"
read -r _pr2 _tip2 _merge2 <<<"$(e2e_pr_squash_keep_branch "$br2" "e2e zmerge A2 ${br2}")"
git clone -q "$(e2e_clone_url)" "$E2E_TMP/other"
git -C "$E2E_TMP/other" config user.email e2e@ceshi.local
git -C "$E2E_TMP/other" config user.name ceshi-e2e
git -C "$E2E_TMP/other" config commit.gpgsign false
git -C "$E2E_TMP/other" fetch -q origin "$br2"
git -C "$E2E_TMP/other" checkout -q "$br2"
printf 'advanced\n' >> "$E2E_TMP/other/e2e-runs/${br2}/note.txt"
git -C "$E2E_TMP/other" add "e2e-runs/${br2}/note.txt"
git -C "$E2E_TMP/other" commit -qm "e2e: advance after squash"
git -C "$E2E_TMP/other" push -q origin "HEAD:refs/heads/${br2}"
moved="$(git -C "$E2E_TMP/other" rev-parse HEAD)"
e2e_remember_tip "$br2" "$moved"
git -C "$E2E_TMP/wt" fetch -q origin "$br2"
setup_z_for "$E2E_TMP/wt" "$br2"
a2rc=0
zmerge_delete_remote_branch >"$E2E_TMP/a2.out" 2>"$E2E_TMP/a2.err" || a2rc=$?
now2="$(git -C "$E2E_TMP/wt" ls-remote origin "refs/heads/${br2}" | awk '{print $1; exit}')"
e2e_expect_eq "40-A2 拒绝删除" 1 "$a2rc"
e2e_expect_eq "40-A2 新 tip 仍在" "$moved" "$now2"

# A3：tip 已是 origin/main 祖先时删除成功（#38 A3 不回归）。
br3="$(e2e_name zmerge-a3)"
main_tip="$(git -C "$E2E_TMP/wt" rev-parse "origin/${SANDBOX_MAIN}")"
git -C "$E2E_TMP/wt" push -q origin "${main_tip}:refs/heads/${br3}"
e2e_register "$br3" "$main_tip"
setup_z_for "$E2E_TMP/wt" "$br3"
a3rc=0
zmerge_delete_remote_branch >"$E2E_TMP/a3.out" 2>"$E2E_TMP/a3.err" || a3rc=$?
e2e_expect_eq "40-A3 祖先路径删除成功" 0 "$a3rc"
e2e_expect_true "40-A3 porcelain deleted" 'grep -Fq "porcelain=deleted" "$E2E_TMP/a3.out"'
e2e_expect_true "40-A3 远端已无分支" \
  '! git -C "$E2E_TMP/wt" ls-remote --exit-code origin "refs/heads/${br3}" >/dev/null 2>&1'
if [ "$a3rc" = 0 ]; then
  e2e_forget "$br3"
fi

e2e_finish
