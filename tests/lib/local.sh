# 本地 SUT 场景。按名字调用现有 completion/Guard/recovery/mutex/finalize 接口。
# 必需文件缺失是失败，不是跳过。

harness_local_relpath() {
  case "$1" in
    mutex-finalize) printf '%s\n' ".agents/skills/zmerge/scripts/check-mutex-finalize.sh" ;;
    squash-body) printf '%s\n' ".agents/skills/zmerge/scripts/check-squash-body.sh" ;;
    claim-resume) printf '%s\n' "0-meta/lib/new/claim-resume.test.sh" ;;
    completion) printf '%s\n' "0-meta/lib/new/completion.test.sh" ;;
    guard) printf '%s\n' "0-meta/lib/new/guard.test.sh" ;;
    guard-issue14) printf '%s\n' "0-meta/lib/new/guard-issue14.test.sh" ;;
    guard-recovery) printf '%s\n' ".agents/skills/zmerge/scripts/check-guard-recovery.sh" ;;
    contract) printf '%s\n' "0-meta/lib/new/contract.test.sh" ;;
    review) printf '%s\n' "0-meta/lib/new/review.test.sh" ;;
    metrics) printf '%s\n' "0-meta/lib/new/metrics.test.sh" ;;
    portable-runtime) printf '%s\n' "0-meta/lib/new/portable-runtime.test.sh" ;;
    setup) printf '%s\n' "0-meta/lib/new/setup.test.sh" ;;
    agent-card) printf '%s\n' "0-meta/lib/new/agent-card.test.sh" ;;
    main-guard) printf '%s\n' "2-infra/git-guard/main_guard_test.py" ;;
    commit) printf '%s\n' "0-meta/bin/new" ;;
    *) return 1 ;;
  esac
}

harness_local_suite_scenarios() {
  case "$1" in
    mutex)
      printf '%s\n' mutex-finalize squash-body claim-resume ;;
    completion)
      printf '%s\n' completion commit ;;
    guard-recovery)
      printf '%s\n' guard guard-issue14 guard-recovery commit ;;
    contract)
      printf '%s\n' contract commit ;;
    metrics)
      printf '%s\n' metrics commit ;;
    v1)
      printf '%s\n' contract review metrics guard portable-runtime setup agent-card main-guard commit ;;
    commit)
      printf '%s\n' commit ;;
    13)
      printf '%s\n' mutex-finalize squash-body claim-resume completion commit ;;
    14)
      printf '%s\n' mutex-finalize squash-body claim-resume guard guard-issue14 guard-recovery commit ;;
    1)
      printf '%s\n' mutex-finalize squash-body claim-resume contract review metrics guard portable-runtime setup agent-card main-guard commit ;;
    33|41)
      printf '%s\n' mutex-finalize squash-body claim-resume contract commit ;;
    42)
      printf '%s\n' mutex-finalize squash-body claim-resume metrics commit ;;
    28|29|30|31)
      printf '%s\n' mutex-finalize squash-body claim-resume commit ;;
    *) return 1 ;;
  esac
}

harness_run_local_scenario() {
  local name sut rel path
  name="$1"
  sut="$2"
  rel=""
  path=""
  rel="$(harness_local_relpath "$name")" || {
    harness_usage_die "未知本地场景：$name"
  }
  path="$sut/$rel"
  if [ ! -f "$path" ]; then
    harness_validation_fail "$name: 必需文件缺失 ${path} (缺少固定测试输入，不转去修 g-lite)"
    return 0
  fi
  if [ ! -e "$path" ]; then
    harness_validation_fail "$name: 必需路径不存在 $path"
    return 0
  fi
  case "$name" in
    main-guard)
      harness_need_cmd python3
      harness_run "$sut" python3 "$path"
      ;;
    commit)
      [ -x "$path" ] || { harness_validation_fail "$name: 不是可执行文件 $path"; return 0; }
      harness_run "$sut" "$path" check --tier commit
      ;;
    *)
      harness_run "$sut" bash "$path"
      ;;
  esac
  harness_require_zero "$name"
}

harness_run_local_list() {
  local sut="$1" name
  shift
  [ $# -gt 0 ] || harness_die "没有要跑的本地场景"
  for name in "$@"; do
    harness_run_local_scenario "$name" "$sut"
  done
}
