#!/usr/bin/env bash
# A1/A2：入口不依赖生命周期；任意 cwd、空格路径；错误输入失败。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/bootstrap.sh
. "$ROOT/tests/lib/bootstrap.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-dispatch.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
RUN="$ROOT/tests/run.sh"

meta_ok=0
meta_bad=0
mok() { meta_ok=$((meta_ok + 1)); printf 'ok  %s\n' "$*"; }
mbad() { meta_bad=$((meta_bad + 1)); printf 'not ok  %s\n' "$*" >&2; }

hits="$(grep -R -n -E 'lib/cmd\.sh|lib/worktree\.sh|lib/common\.sh|lib/github\.sh|worktree_find|g_lite_open_queue|cmd_start|sut_code_root|CESHI_SUT_CODE' \
  "$ROOT/tests/run.sh" \
  "$ROOT/tests/lib" \
  "$ROOT/tests/e2e" \
  || true)"
if [ -z "$hits" ]; then
  mok "新入口不引用生命周期模块"
else
  mbad "新入口仍引用生命周期："
  printf '%s\n' "$hits" >&2
fi

cd "$tmp"
if bash "$RUN" helpers >"$tmp/from-tmp.out" 2>"$tmp/from-tmp.err"; then
  mok "从非仓库 cwd 运行 helpers"
else
  mbad "从非仓库 cwd 运行 helpers 失败"
  cat "$tmp/from-tmp.out" "$tmp/from-tmp.err" >&2 || :
fi

space_link="$tmp/harness root"
space_wd="$tmp/test workdir"
ln -s "$ROOT" "$space_link"
mkdir -p "$space_wd"
if (cd "$space_wd" && bash "$space_link/tests/helpers/identity.test.sh") \
  >"$tmp/space.out" 2>"$tmp/space.err"; then
  mok "含空格的 Harness 路径与 workdir"
else
  mbad "含空格路径运行失败"
  cat "$tmp/space.out" "$tmp/space.err" >&2 || :
fi

rc=0
bash "$RUN" definitely-not-a-scene >"$tmp/unk.out" 2>"$tmp/unk.err" || rc=$?
if [ "$rc" = 2 ] && grep -q '未知场景' "$tmp/unk.err"; then
  mok "未知场景明确失败 rc=2"
else
  mbad "未知场景 rc=$rc"
fi

rc=0
bash "$RUN" local --scenario completion >"$tmp/nosut.out" 2>"$tmp/nosut.err" || rc=$?
if [ "$rc" != 0 ] && grep -q -- '--sut' "$tmp/nosut.err"; then
  mok "缺少 --sut 明确失败"
else
  mbad "缺少 --sut 未失败 rc=$rc"
  cat "$tmp/nosut.out" "$tmp/nosut.err" >&2 || :
fi

rc=0
bash "$RUN" local --scenario completion --sut "$tmp/no-such-sut" --no-isolate \
  >"$tmp/badsut.out" 2>"$tmp/badsut.err" || rc=$?
if [ "$rc" != 0 ]; then
  mok "SUT 路径错误明确失败"
else
  mbad "错误 SUT 路径静默通过"
fi

wrong="$tmp/wrong-origin"
harness_mk_git_repo "$wrong" "https://github.com/qiaoen12/g-lite-harness.git"
rm -f "$wrong/.harness-sut-fixture"
rc=0
bash "$RUN" local --scenario completion --sut "$wrong" --no-isolate \
  >"$tmp/wrong.out" 2>"$tmp/wrong.err" || rc=$?
if [ "$rc" != 0 ] && grep -q 'origin' "$tmp/wrong.err"; then
  mok "仓库身份不符明确失败"
else
  mbad "错误 origin 未失败 rc=$rc"
  cat "$tmp/wrong.out" "$tmp/wrong.err" >&2 || :
fi

rc=0
bash "$RUN" local --scenario not-a-real-scenario --sut "$wrong" --no-isolate \
  >"$tmp/badsc.out" 2>"$tmp/badsc.err" || rc=$?
if [ "$rc" = 2 ]; then
  mok "未知本地场景明确失败"
else
  mbad "未知本地场景 rc=$rc"
fi

src="$tmp/unchanged-src"
harness_mk_git_repo "$src"
before_head="$(git -C "$src" rev-parse HEAD)"
before_porc="$(git -C "$src" status --porcelain)"
rc=0
bash "$RUN" local --scenario completion --sut "$src" --no-isolate \
  >"$tmp/unchanged.out" 2>"$tmp/unchanged.err" || rc=$?
after_head="$(git -C "$src" rev-parse HEAD)"
after_porc="$(git -C "$src" status --porcelain)"
if [ "$rc" != 0 ] && [ "$before_head" = "$after_head" ] && [ "$before_porc" = "$after_porc" ]; then
  mok "隔离/失败路径不改变源 checkout"
else
  mbad "源 checkout 被改动或意外成功 rc=$rc"
fi

iso_src="$tmp/isolate-src"
harness_mk_git_repo "$iso_src"
iso_head="$(git -C "$iso_src" rev-parse HEAD)"
rc=0
bash "$RUN" local --scenario completion --sut "$iso_src" \
  >"$tmp/iso.out" 2>"$tmp/iso.err" || rc=$?
iso_after="$(git -C "$iso_src" rev-parse HEAD)"
iso_wd="$(awk -F= '/^SUT_WORKDIR=/{print $2; exit}' "$tmp/iso.out")"
iso_origin=""
[ -n "$iso_wd" ] && iso_origin="$(git -C "$iso_wd" remote get-url origin 2>/dev/null || true)"
if [ "$rc" != 0 ] && [ "$iso_head" = "$iso_after" ] \
  && grep -q 'SUT_WORKDIR=' "$tmp/iso.out" \
  && ! grep -q '隔离目录已存在' "$tmp/iso.err" \
  && [ "$iso_origin" = "https://github.com/qiaoen12/g-lite.git" ]; then
  mok "默认 --isolate 复制到空目录并保持源 origin"
else
  mbad "默认 isolate 失败 rc=$rc origin=$iso_origin"
  cat "$tmp/iso.out" "$tmp/iso.err" >&2 || :
fi

echo "dispatch-meta ${meta_ok} pass, ${meta_bad} fail"
[ "$meta_bad" = 0 ]
[ "$meta_ok" -gt 0 ]
