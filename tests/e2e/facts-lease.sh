#!/usr/bin/env bash
# 精确 lease：读到的 tip 被推进后，不得删成无 lease。
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

br="$(e2e_name lease)"
e2e_push_branch "$E2E_TMP/wt" "$br" "e2e-runs/${br}/note.txt"
old_tip="$(git -C "$E2E_TMP/wt" rev-parse HEAD)"

git clone -q "$(e2e_clone_url)" "$E2E_TMP/other"
git -C "$E2E_TMP/other" config user.email e2e@ceshi.local
git -C "$E2E_TMP/other" config user.name ceshi-e2e
git -C "$E2E_TMP/other" config commit.gpgsign false
git -C "$E2E_TMP/other" fetch -q origin "$br"
git -C "$E2E_TMP/other" checkout -q "$br"
printf 'moved\n' >> "$E2E_TMP/other/e2e-runs/${br}/note.txt"
git -C "$E2E_TMP/other" add "e2e-runs/${br}/note.txt"
git -C "$E2E_TMP/other" commit -qm "e2e: advance ${br}"
git -C "$E2E_TMP/other" push -q origin "HEAD:refs/heads/${br}"
new_tip="$(git -C "$E2E_TMP/other" rev-parse HEAD)"
e2e_remember_tip "$br" "$new_tip"

rc=0
git -C "$E2E_TMP/wt" push --porcelain \
  --force-with-lease="refs/heads/${br}:${old_tip}" \
  origin ":refs/heads/${br}" >/dev/null 2>"$E2E_TMP/lease.err" || rc=$?

now="$(git -C "$E2E_TMP/wt" ls-remote origin "refs/heads/${br}" | awk '{print $1; exit}')"
e2e_expect_true "旧 tip lease 删除必须失败" '[ "$rc" != 0 ]'
e2e_expect_eq "推进后的 tip 仍在" "$new_tip" "$now"

git -C "$E2E_TMP/wt" push --porcelain \
  --force-with-lease="refs/heads/${br}:${new_tip}" \
  origin ":refs/heads/${br}" >/dev/null
e2e_forget "$br"
e2e_expect_true "正确 lease 可以删除" \
  '! git -C "$E2E_TMP/wt" ls-remote --exit-code origin "refs/heads/${br}" >/dev/null 2>&1'

e2e_finish
