#!/usr/bin/env bash
# Harness 测试薄入口。从任意 cwd 用本脚本路径定位资源；不读 Issue 队列。
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
. "$HERE/lib/bootstrap.sh"

usage() {
  cat <<'EOF'
tests/run.sh <scene> [选项]

  helpers              解析器 + 身份钉死（不上网）
  result               结果记录夹具（成功/断言失败/缺程序/非零无输出/管道/缺必需/cleanup）
  dispatch             cwd、空格路径、未知场景、错误输入
  sandbox-local        错误 repo/base、缺 opt-in、已有对象、tip 漂移（不写 GitHub）
  selfcheck            以上全部（Harness 自检，不需要 --sut）
  local --suite NAME --sut PATH
  local --scenario NAME --sut PATH
  facts --yes          真实 squash / lease / Refs-Fixes
  zmerge-delete --sut PATH --yes
                       只验 zmerge_delete_remote_branch，不是完整 zmerge_run

选项：
  --sut PATH           外部被测代码，必须显式给出
  --suite NAME         13/14/1/33/41/42/mutex/completion/guard-recovery/contract/...
  --scenario NAME      单个调用接口
  --workdir PATH       显式测试 workdir（可含空格）
  --isolate            默认：隔离复制 SUT
  --no-isolate         仅临时目录或 .harness-sut-fixture
  --yes                真实 GitHub 写入 opt-in（HARNESS_E2E_YES=1）

旧入口对照见 tests/MIGRATION.md。
EOF
}

scene="${1:-}"
if [ -z "$scene" ]; then
  usage
  harness_usage_die "缺少 scene"
fi
shift

HARNESS_SCENE="$scene"
SUT=""
SCENARIO=""
SUITE=""
WORKDIR=""
ISOLATE=1
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --yes) HARNESS_E2E_YES=1; CESHI_YES=1; shift ;;
    --sut)
      [ -n "${2:-}" ] || harness_usage_die "--sut 需要路径"
      SUT="$2"
      shift 2
      ;;
    --scenario)
      [ -n "${2:-}" ] || harness_usage_die "--scenario 需要名字"
      SCENARIO="$2"
      shift 2
      ;;
    --suite)
      [ -n "${2:-}" ] || harness_usage_die "--suite 需要名字"
      SUITE="$2"
      shift 2
      ;;
    --workdir)
      [ -n "${2:-}" ] || harness_usage_die "--workdir 需要路径"
      WORKDIR="$2"
      shift 2
      ;;
    --isolate) ISOLATE=1; shift ;;
    --no-isolate) ISOLATE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) harness_usage_die "未知选项：$1" ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

if [ "$scene" = zmerge ]; then
  scene=zmerge-delete
  HARNESS_SCENE="$scene"
fi

if [ "${#POSITIONAL[@]}" -gt 0 ]; then
  legacy="${POSITIONAL[0]}"
  if [ "${#POSITIONAL[@]}" -gt 1 ]; then
    harness_usage_die "多余参数：${POSITIONAL[*]}"
  fi
  case "$scene" in
    local)
      [ -z "$SUITE$SCENARIO" ] || harness_usage_die "不要同时给位置参数和 --suite/--scenario"
      SUITE="$legacy"
      ;;
    zmerge-delete)
      printf '忽略旧 Issue 号 %s：SUT 必须由 --sut 提供\n' "$legacy"
      ;;
    *)
      harness_usage_die "多余参数：$legacy"
      ;;
  esac
fi

run_script() {
  local script="$1"
  [ -f "$script" ] || harness_die "找不到测试脚本：$script"
  bash "$script"
}

run_helpers() {
  run_script "$HARNESS_ROOT/tests/helpers/parse.test.sh"
  run_script "$HARNESS_ROOT/tests/helpers/guard.test.sh"
  run_script "$HARNESS_ROOT/tests/helpers/identity.test.sh"
}

prepare_sut_or_die() {
  [ -n "$SUT" ] || harness_die "此 scene 需要 --sut PATH，禁止从队列或 g-lite main fallback"
  harness_prepare_sut "$SUT" "$ISOLATE" "$WORKDIR"
  export HARNESS_SUT HARNESS_SUT_SOURCE HARNESS_SUT_SOURCE_HEAD
}

run_local() {
  local names=() name
  if [ -n "$SCENARIO" ] && [ -n "$SUITE" ]; then
    harness_usage_die "同时指定了 --suite 和 --scenario"
  fi
  if [ -n "$SCENARIO" ]; then
    harness_local_relpath "$SCENARIO" >/dev/null \
      || harness_usage_die "未知本地场景：$SCENARIO"
    names=("$SCENARIO")
  elif [ -n "$SUITE" ]; then
    local listed
    listed="$(harness_local_suite_scenarios "$SUITE")" \
      || harness_usage_die "未知 suite：$SUITE"
    # shellcheck disable=SC2206
    names=($listed)
  else
    harness_usage_die "local 需要 --suite NAME 或 --scenario NAME"
  fi
  prepare_sut_or_die
  harness_print_ident
  for name in "${names[@]}"; do
    harness_run_local_scenario "$name" "$HARNESS_SUT"
  done
  harness_assert_source_unchanged
  harness_finish
}

run_facts() {
  harness_print_ident
  bash "$HARNESS_ROOT/tests/e2e/facts-squash.sh" --yes
  bash "$HARNESS_ROOT/tests/e2e/facts-lease.sh" --yes
  bash "$HARNESS_ROOT/tests/e2e/refs-fixes.sh" --yes
}

run_zmerge_delete() {
  prepare_sut_or_die
  harness_print_ident
  printf '删除函数来自：%s\n' "$HARNESS_SUT"
  printf '范围：zmerge_delete_remote_branch 的真实 GitHub 集成测试，不是完整 zmerge_run。\n'
  bash "$HARNESS_ROOT/tests/e2e/zmerge-delete.sh" --yes --sut "$HARNESS_SUT"
  harness_assert_source_unchanged
}

run_selfcheck() {
  local rc=0
  run_helpers || rc=1
  run_script "$HARNESS_ROOT/tests/helpers/result.test.sh" || rc=1
  run_script "$HARNESS_ROOT/tests/helpers/dispatch.test.sh" || rc=1
  run_script "$HARNESS_ROOT/tests/helpers/sandbox.test.sh" || rc=1
  return "$rc"
}

case "$scene" in
  helpers)
    harness_print_ident
    run_helpers
    ;;
  result)
    harness_print_ident
    run_script "$HARNESS_ROOT/tests/helpers/result.test.sh"
    ;;
  dispatch)
    harness_print_ident
    run_script "$HARNESS_ROOT/tests/helpers/dispatch.test.sh"
    ;;
  sandbox-local)
    harness_print_ident
    run_script "$HARNESS_ROOT/tests/helpers/sandbox.test.sh"
    ;;
  selfcheck)
    harness_print_ident
    run_selfcheck
    ;;
  local)
    run_local
    ;;
  facts)
    run_facts
    ;;
  zmerge-delete)
    run_zmerge_delete
    ;;
  *)
    usage
    harness_usage_die "未知场景：$scene"
    ;;
esac
