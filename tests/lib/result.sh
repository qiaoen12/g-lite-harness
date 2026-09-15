# 记录命令、cwd、原始退出码和输出。不是通用状态机。
# 分类：PASS / VALIDATION_FAIL / EXECUTION_ERROR；可选 SKIP 不能代替必需检查。

HARNESS_PASS=0
HARNESS_VALIDATION_FAIL=0
HARNESS_EXECUTION_ERROR=0
HARNESS_SKIP=0
HARNESS_REQUIRED_RAN=0

HARNESS_LAST_RC=0
HARNESS_LAST_STDOUT=""
HARNESS_LAST_STDERR=""
HARNESS_LAST_CWD=""
HARNESS_LAST_CMD=""

harness_pass() {
  HARNESS_PASS=$((HARNESS_PASS + 1))
  HARNESS_REQUIRED_RAN=$((HARNESS_REQUIRED_RAN + 1))
  printf 'PASS %s\n' "$*"
}

harness_validation_fail() {
  HARNESS_VALIDATION_FAIL=$((HARNESS_VALIDATION_FAIL + 1))
  HARNESS_REQUIRED_RAN=$((HARNESS_REQUIRED_RAN + 1))
  printf 'VALIDATION_FAIL %s\n' "$*" >&2
}

harness_execution_error() {
  HARNESS_EXECUTION_ERROR=$((HARNESS_EXECUTION_ERROR + 1))
  HARNESS_REQUIRED_RAN=$((HARNESS_REQUIRED_RAN + 1))
  printf 'EXECUTION_ERROR %s\n' "$*" >&2
}

harness_skip() {
  HARNESS_SKIP=$((HARNESS_SKIP + 1))
  printf 'SKIP %s\n' "$*"
}

harness_record() {
  printf 'CMD %s\n' "$HARNESS_LAST_CMD"
  printf 'CWD %s\n' "$HARNESS_LAST_CWD"
  printf 'RC %s\n' "$HARNESS_LAST_RC"
  printf 'STDOUT_BEGIN\n%s\nSTDOUT_END\n' "$HARNESS_LAST_STDOUT"
  printf 'STDERR_BEGIN\n%s\nSTDERR_END\n' "$HARNESS_LAST_STDERR"
}

# 运行命令并保留原始 rc。exit 2 按命令语义留给调用方，不在这里改写成执行器异常。
harness_run() {
  local workdir="$1"
  shift
  local out err
  [ -n "$workdir" ] || harness_die "harness_run 需要显式 workdir"
  [ -d "$workdir" ] || harness_die "workdir 不存在：$workdir"
  out="$(mktemp "${TMPDIR:-/tmp}/harness-out.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/harness-err.XXXXXX")"
  HARNESS_LAST_CWD="$workdir"
  HARNESS_LAST_CMD="$*"
  HARNESS_LAST_RC=0
  (
    cd "$workdir" || exit 127
    "$@"
  ) >"$out" 2>"$err" || HARNESS_LAST_RC=$?
  HARNESS_LAST_STDOUT="$(cat "$out")"
  HARNESS_LAST_STDERR="$(cat "$err")"
  rm -f "$out" "$err"
  harness_record
}

harness_require_zero() {
  local name="$1"
  if [ "$HARNESS_LAST_RC" -eq 127 ]; then
    harness_execution_error "$name: 找不到执行程序或无法进入 cwd（rc=127）"
  elif [ "$HARNESS_LAST_RC" -ne 0 ]; then
    harness_validation_fail "$name: 期望 rc=0 实际 rc=${HARNESS_LAST_RC}"
  else
    harness_pass "$name"
  fi
}

# 预期负向退出。必须真的执行过；rc=0 或 127 不能当成“检查失败”。
harness_require_nonzero() {
  local name="$1"
  if [ "$HARNESS_LAST_RC" -eq 127 ]; then
    harness_execution_error "$name: 命令未执行（rc=127）"
  elif [ "$HARNESS_LAST_RC" -eq 0 ]; then
    harness_validation_fail "$name: 期望非零但 rc=0（检查可能未执行）"
  else
    harness_pass "$name: 负向 rc=${HARNESS_LAST_RC}"
  fi
}

harness_expect_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    harness_pass "$name"
  else
    harness_validation_fail "$name: 期望 [$expected] 实际 [$actual]"
  fi
}

harness_finish() {
  printf 'summary PASS=%s VALIDATION_FAIL=%s EXECUTION_ERROR=%s SKIP=%s REQUIRED_RAN=%s\n' \
    "$HARNESS_PASS" "$HARNESS_VALIDATION_FAIL" "$HARNESS_EXECUTION_ERROR" \
    "$HARNESS_SKIP" "$HARNESS_REQUIRED_RAN"
  if [ "$HARNESS_REQUIRED_RAN" -eq 0 ]; then
    printf '没有执行任何必需检查，拒绝以零项成功退出\n' >&2
    return 1
  fi
  if [ "$HARNESS_VALIDATION_FAIL" -ne 0 ] || [ "$HARNESS_EXECUTION_ERROR" -ne 0 ]; then
    return 1
  fi
  return 0
}

harness_evidence_file() {
  mkdir -p "$HARNESS_ROOT/.tmp/evidence"
  printf '%s/run-%s-%s.md\n' "$HARNESS_ROOT/.tmp/evidence" "$(date -u +%Y%m%d%H%M%S)" "$$"
}

harness_evidence_write() {
  local file="$1"
  cat >"$file" <<EOF
# Harness 测试证据

| 项 | 值 |
| --- | --- |
| time (UTC) | $(date -u +%Y-%m-%dT%H:%M:%SZ) |
| scene | ${HARNESS_SCENE:-} |
| harness_root | \`$HARNESS_ROOT\` |
| harness_head | \`$(harness_head "$HARNESS_ROOT")\` |
| sut_source | \`${HARNESS_SUT_SOURCE:-（无）}\` |
| sut_source_head | \`${HARNESS_SUT_SOURCE_HEAD:-（无）}\` |
| sut_workdir | \`${HARNESS_SUT:-（无）}\` |
| leftover | ${HARNESS_LEFTOVER:-（无）} |
| PASS | ${HARNESS_PASS} |
| VALIDATION_FAIL | ${HARNESS_VALIDATION_FAIL} |
| EXECUTION_ERROR | ${HARNESS_EXECUTION_ERROR} |
| SKIP | ${HARNESS_SKIP} |

EOF
  printf 'evidence %s\n' "$file"
}
