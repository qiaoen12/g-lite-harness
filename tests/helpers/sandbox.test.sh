#!/usr/bin/env bash
# A4：危险负向场景在真实写入前被拒绝（本地 git，不上 GitHub）。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/bootstrap.sh
. "$ROOT/tests/lib/bootstrap.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-sandbox.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

meta_ok=0
meta_bad=0
mok() { meta_ok=$((meta_ok + 1)); printf 'ok  %s\n' "$*"; }
mbad() { meta_bad=$((meta_bad + 1)); printf 'not ok  %s\n' "$*" >&2; }

if (SANDBOX_REPO=evil/other; harness_require_pins); then
  mbad "改 SANDBOX_REPO 后 pins 仍通过"
else
  mok "错误 repo 变量无法通过 pins"
fi

# 重新钉死后再测函数门禁。
# shellcheck source=../lib/identity.sh
. "$ROOT/tests/lib/identity.sh"

if (harness_require_write_repo qiaoen12/g-lite); then
  mbad "写入 g-lite 未被拒绝"
else
  mok "错误 repo：拒绝写入 g-lite"
fi

if (harness_require_squash_base main); then
  mbad "squash 进 main 未被拒绝"
else
  mok "错误 base：拒绝 squash 进 main"
fi

if (harness_require_e2e_branch main); then
  mbad "操作 main 未被拒绝"
else
  mok "拒绝操作 main"
fi

if (harness_require_e2e_branch e2e/base); then
  mbad "操作 e2e/base 未被拒绝"
else
  mok "拒绝操作持久 e2e/base"
fi

if (harness_require_e2e_branch feature/foo); then
  mbad "非 e2e 分支未被拒绝"
else
  mok "拒绝非 e2e/* 分支"
fi

if (harness_require_e2e_branch 'e2e/ok-1'); then
  mok "合法 e2e 分支通过"
else
  mbad "合法 e2e 分支被拒"
fi

unset HARNESS_E2E_YES CESHI_YES || true
if (harness_require_e2e_opt_in); then
  mbad "缺 opt-in 未被拒绝"
else
  mok "缺 opt-in：真实写入前拒绝"
fi

HARNESS_E2E_YES=1
if (harness_require_e2e_opt_in); then
  mok "显式 opt-in 通过"
else
  mbad "opt-in 后仍拒绝"
fi
unset HARNESS_E2E_YES

git init --bare --quiet "$tmp/origin.git"
mkdir -p "$tmp/wt"
git -C "$tmp/wt" init --quiet
git -C "$tmp/wt" config user.email harness-fixture@local
git -C "$tmp/wt" config user.name harness-fixture
git -C "$tmp/wt" config commit.gpgsign false
git -C "$tmp/wt" remote add origin "$tmp/origin.git"
printf 'base\n' >"$tmp/wt/README"
git -C "$tmp/wt" add README
git -C "$tmp/wt" commit --quiet -m init
git -C "$tmp/wt" push --quiet origin HEAD:refs/heads/e2e-base-local
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/e2e-base-local

br='e2e/existing-retry'
git -C "$tmp/wt" checkout --quiet -b "$br"
printf 'one\n' >"$tmp/wt/note.txt"
git -C "$tmp/wt" add note.txt
git -C "$tmp/wt" commit --quiet -m 'e2e existing'
git -C "$tmp/wt" push --quiet origin "HEAD:refs/heads/${br}"
owned="$(git -C "$tmp/wt" rev-parse HEAD)"

if (harness_e2e_reject_if_remote_exists "$tmp/wt" "$br"); then
  mbad "已有远端对象未被拒绝"
else
  mok "已有对象/重试：拒绝覆盖"
fi

git clone --quiet "$tmp/origin.git" "$tmp/other"
git -C "$tmp/other" config user.email harness-fixture@local
git -C "$tmp/other" config user.name harness-fixture
git -C "$tmp/other" config commit.gpgsign false
git -C "$tmp/other" fetch --quiet origin "$br"
git -C "$tmp/other" checkout --quiet "$br"
printf 'moved\n' >>"$tmp/other/note.txt"
git -C "$tmp/other" add note.txt
git -C "$tmp/other" commit --quiet -m advance
git -C "$tmp/other" push --quiet origin "HEAD:refs/heads/${br}"
moved="$(git -C "$tmp/other" rev-parse HEAD)"

rc=0
harness_e2e_delete_owned_branch "$tmp/wt" "$br" "$owned" || rc=$?
now="$(harness_e2e_remote_tip "$tmp/wt" "$br")"
if [ "$rc" = 2 ] && [ "$now" = "$moved" ]; then
  mok "tip 漂移：不强删且新 tip 仍在"
else
  mbad "tip 漂移处理错误 rc=$rc now=$now expected=$moved"
fi

rc=0
harness_e2e_delete_owned_branch "$tmp/wt" "$br" "$moved" || rc=$?
gone="$(harness_e2e_remote_tip "$tmp/wt" "$br")"
if [ "$rc" = 0 ] && [ -z "$gone" ]; then
  mok "正确 lease 可以删除本次拥有的 tip"
else
  mbad "正确 lease 删除失败 rc=$rc gone=$gone"
fi

echo "sandbox-meta ${meta_ok} pass, ${meta_bad} fail"
[ "$meta_bad" = 0 ]
[ "$meta_ok" -gt 0 ]
