# 沙箱写入门禁。叶子脚本也必须走这里，环境变量不能换仓。

harness_sandbox_pins_ok() {
  [ "$HARNESS_SUT_REPO" = qiaoen12/g-lite ] || return 1
  [ "$HARNESS_SUT_MAIN" = main ] || return 1
  [ "$HARNESS_SANDBOX_REPO" = qiaoen12/g-lite-harness ] || return 1
  [ "$HARNESS_SANDBOX_MAIN" = e2e/base ] || return 1
  [ "$HARNESS_E2E_PREFIX" = 'e2e/' ] || return 1
  [ "$SUT_REPO" = "$HARNESS_SUT_REPO" ] || return 1
  [ "$SANDBOX_REPO" = "$HARNESS_SANDBOX_REPO" ] || return 1
  [ "$SANDBOX_MAIN" = "$HARNESS_SANDBOX_MAIN" ] || return 1
  [ "$E2E_BRANCH_PREFIX" = "$HARNESS_E2E_PREFIX" ] || return 1
}

harness_require_pins() {
  harness_sandbox_pins_ok || harness_die "沙箱/被测仓身份被改写，拒绝继续"
}

harness_require_write_repo() {
  local repo="$1"
  harness_require_pins
  [ "$repo" = "$HARNESS_SANDBOX_REPO" ] \
    || harness_die "拒绝写入非沙箱仓：${repo} (只允许 ${HARNESS_SANDBOX_REPO})"
}

harness_require_squash_base() {
  local base="$1"
  [ "$base" = "$HARNESS_SANDBOX_MAIN" ] \
    || harness_die "squash 只允许进入 ${HARNESS_SANDBOX_MAIN}，拒绝 base=$base"
}

harness_require_e2e_branch() {
  local br="$1"
  harness_require_pins
  case "$br" in
    "${HARNESS_E2E_PREFIX}"*) ;;
    *) harness_die "拒绝操作非 ${HARNESS_E2E_PREFIX} 分支：$br" ;;
  esac
  [ "$br" != "$HARNESS_SANDBOX_MAIN" ] || harness_die "拒绝操作持久 base：${HARNESS_SANDBOX_MAIN}"
  [ "$br" != main ] || harness_die "拒绝操作默认分支名 main"
  branch_ok "$br" || harness_die "非法分支名：$br"
}

harness_require_e2e_opt_in() {
  if [ "${CESHI_YES:-}" = 1 ]; then
    HARNESS_E2E_YES=1
  fi
  if [ "${HARNESS_E2E_YES:-}" = 1 ]; then
    return 0
  fi
  harness_die "真实 GitHub 测试会改 ${HARNESS_SANDBOX_REPO} 的 e2e/*（squash 进 ${HARNESS_SANDBOX_MAIN}）。加上 --yes 或 HARNESS_E2E_YES=1"
}

harness_gh() {
  GH_PAGER=cat gh "$@"
}

harness_sandbox_name_with_owner() {
  harness_gh repo view "$HARNESS_SANDBOX_REPO" --json nameWithOwner -q .nameWithOwner
}

harness_sandbox_default_branch() {
  harness_gh repo view "$HARNESS_SANDBOX_REPO" --json defaultBranchRef \
    -q .defaultBranchRef.name
}

harness_sandbox_has_e2e_base() {
  local sha
  sha="$(harness_gh api "repos/${HARNESS_SANDBOX_REPO}/git/ref/heads/${HARNESS_SANDBOX_MAIN}" \
    --jq .object.sha 2>/dev/null)" || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]]
}

harness_require_sandbox_repo() {
  local got
  harness_require_pins
  harness_require_write_repo "$HARNESS_SANDBOX_REPO"
  got="$(harness_sandbox_name_with_owner)" \
    || harness_die "读不到沙箱仓 ${HARNESS_SANDBOX_REPO}"
  [ "$got" = qiaoen12/g-lite-harness ] \
    || harness_die "沙箱仓实际是 ${got}，必须是 qiaoen12/g-lite-harness"
}

# 兼容旧 e2e 脚本函数名。
require_e2e_branch() { harness_require_e2e_branch "$@"; }
require_sandbox_repo() { harness_require_sandbox_repo "$@"; }
require_e2e_confirm() { harness_require_e2e_opt_in "$@"; }
sandbox_name_with_owner() { harness_sandbox_name_with_owner "$@"; }
sandbox_default_branch() { harness_sandbox_default_branch "$@"; }
sandbox_has_e2e_base() { harness_sandbox_has_e2e_base "$@"; }
gh_json() { harness_gh "$@"; }
e2e_name() {
  local kind="$1"
  printf '%s%s-%s-%s\n' "$HARNESS_E2E_PREFIX" "$kind" "$(date -u +%Y%m%d%H%M%S)" "$$"
}
