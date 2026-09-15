#!/usr/bin/env bash
# A3：结果记录夹具。内层失败要被正确分类；本脚本本身必须绿。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/bootstrap.sh
. "$ROOT/tests/lib/bootstrap.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-result.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

meta_ok=0
meta_bad=0
mok() { meta_ok=$((meta_ok + 1)); printf 'ok  %s\n' "$*"; }
mbad() { meta_bad=$((meta_bad + 1)); printf 'not ok  %s\n' "$*" >&2; }

reset_counters() {
  HARNESS_PASS=0
  HARNESS_VALIDATION_FAIL=0
  HARNESS_EXECUTION_ERROR=0
  HARNESS_SKIP=0
  HARNESS_REQUIRED_RAN=0
}

reset_counters
harness_run "$tmp" true
harness_require_zero success-true
if [ "$HARNESS_PASS" = 1 ] && [ "$HARNESS_VALIDATION_FAIL" = 0 ] && [ "$HARNESS_LAST_RC" = 0 ]; then
  mok "成功：rc=0 记 PASS"
else
  mbad "成功未记 PASS pass=$HARNESS_PASS rc=$HARNESS_LAST_RC"
fi

reset_counters
harness_expect_eq "assert-demo" foo bar
if [ "$HARNESS_VALIDATION_FAIL" = 1 ] && [ "$HARNESS_PASS" = 0 ]; then
  mok "断言失败：VALIDATION_FAIL"
else
  mbad "断言失败分类错误 fail=$HARNESS_VALIDATION_FAIL"
fi

reset_counters
harness_run "$tmp" "$tmp/no-such-harness-exec-$$"
harness_require_zero missing-exec
if [ "$HARNESS_EXECUTION_ERROR" = 1 ]; then
  mok "缺执行程序：EXECUTION_ERROR rc=$HARNESS_LAST_RC"
else
  mbad "缺执行程序未记 EXECUTION_ERROR rc=$HARNESS_LAST_RC exec=$HARNESS_EXECUTION_ERROR"
fi

reset_counters
harness_run "$tmp" bash "$ROOT/tests/fixtures/result/silent-fail.sh"
if [ "$HARNESS_LAST_RC" != 0 ] && [ -z "$HARNESS_LAST_STDOUT" ] && [ -z "$HARNESS_LAST_STDERR" ]; then
  mok "非零无输出：rc=${HARNESS_LAST_RC} 未被空输出吞掉"
else
  mbad "非零无输出记录错误 rc=$HARNESS_LAST_RC out=[$HARNESS_LAST_STDOUT] err=[$HARNESS_LAST_STDERR]"
fi
harness_require_zero silent-nonzero
if [ "$HARNESS_VALIDATION_FAIL" = 1 ]; then
  mok "非零无输出：VALIDATION_FAIL（不是执行器异常）"
else
  mbad "非零无输出分类错误 fail=$HARNESS_VALIDATION_FAIL exec=$HARNESS_EXECUTION_ERROR"
fi

reset_counters
harness_run "$tmp" bash -c 'set -o pipefail; false | true'
if [ "$HARNESS_LAST_RC" != 0 ]; then
  mok "管道上游失败：pipefail rc=${HARNESS_LAST_RC}"
else
  mbad "管道上游失败被末端 true 掩盖"
fi
harness_require_zero pipeline-upstream
if [ "$HARNESS_VALIDATION_FAIL" = 1 ]; then
  mok "管道上游失败：VALIDATION_FAIL"
else
  mbad "管道失败分类错误 fail=$HARNESS_VALIDATION_FAIL"
fi

ws="$tmp/whitespace"
mkdir -p "$ws"
git -C "$ws" init --quiet
git -C "$ws" config user.email harness-fixture@local
git -C "$ws" config user.name harness-fixture
git -C "$ws" config commit.gpgsign false
printf 'hello  \n' >"$ws/note.txt"
git -C "$ws" add note.txt
reset_counters
harness_run "$ws" git diff --check --cached
if [ "$HARNESS_LAST_RC" != 0 ]; then
  mok "git diff --check 真实空白 rc=${HARNESS_LAST_RC}"
else
  mbad "git diff --check 未对空白失败"
fi
harness_require_zero whitespace-check
if [ "$HARNESS_VALIDATION_FAIL" = 1 ] && [ "$HARNESS_EXECUTION_ERROR" = 0 ]; then
  mok "git diff --check 非零不按执行器异常处理"
else
  mbad "git diff --check 分类错误 fail=$HARNESS_VALIDATION_FAIL exec=$HARNESS_EXECUTION_ERROR"
fi

missing="$tmp/missing-required"
harness_mk_git_repo "$missing"
reset_counters
rc=0
bash "$ROOT/tests/run.sh" local --scenario completion --sut "$missing" --no-isolate \
  >"$tmp/missing.out" 2>"$tmp/missing.err" || rc=$?
if [ "$rc" != 0 ] && grep -q '必需文件缺失' "$tmp/missing.out" "$tmp/missing.err"; then
  mok "必需项缺失：拒绝静默通过 rc=$rc"
else
  mbad "必需项缺失未失败 rc=$rc"
  cat "$tmp/missing.out" "$tmp/missing.err" >&2 || :
fi

cleanup_demo() {
  printf 'LEFTOVER object=e2e/cleanup-demo\n'
  printf 'RECOVERY: git push origin :refs/heads/e2e/cleanup-demo\n'
  return 1
}

orig_rc=3
clean_rc=0
cleanup_out="$(cleanup_demo 2>&1)" || clean_rc=$?
kept="$orig_rc"
if [ "$orig_rc" -eq 0 ] && [ "$clean_rc" -ne 0 ]; then
  kept=1
fi
if [ "$kept" = 3 ] && [ "$clean_rc" = 1 ] && printf '%s\n' "$cleanup_out" | grep -q 'LEFTOVER object=e2e/cleanup-demo'; then
  mok "cleanup 失败保留原 rc=3 并报告残留"
else
  mbad "cleanup 原失败结果未保留 kept=$kept clean=$clean_rc"
fi

orig_rc=0
clean_rc=0
cleanup_demo >/dev/null || clean_rc=$?
overall="$orig_rc"
if [ "$orig_rc" -eq 0 ] && [ "$clean_rc" -ne 0 ]; then
  overall=1
fi
if [ "$overall" = 1 ]; then
  mok "cleanup 失败在原测试通过时仍让总结果失败"
else
  mbad "cleanup 失败被忽略 overall=$overall"
fi

reset_counters
harness_skip "optional demo: 不替代必需验收"
if harness_finish; then
  mbad "只有 SKIP 时不能成功退出"
else
  mok "只有 SKIP：拒绝零项必需检查成功"
fi

echo "result-meta ${meta_ok} pass, ${meta_bad} fail"
[ "$meta_bad" = 0 ]
[ "$meta_ok" -gt 0 ]
