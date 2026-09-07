# gh 封装。目标仓只读 Issue/PR；写操作必须显式指向沙箱仓或 Draft PR。

gh_json() {
  GH_PAGER=cat gh "$@"
}

sut_issue_json() {
  local n="$1"
  gh_json issue view "$n" --repo "$SUT_REPO" --json \
    number,title,body,state,labels,url
}

sut_issue_labels() {
  local json="$1"
  printf '%s' "$json" | jq -r '.labels[].name'
}

sandbox_name_with_owner() {
  gh_json repo view "$SANDBOX_REPO" --json nameWithOwner -q .nameWithOwner
}

sandbox_default_branch() {
  gh_json repo view "$SANDBOX_REPO" --json defaultBranchRef \
    -q .defaultBranchRef.name
}

sandbox_has_main_commit() {
  local sha
  sha="$(gh_json api "repos/${SANDBOX_REPO}/commits/${SANDBOX_MAIN}" --jq .sha 2>/dev/null)" || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]]
}

require_sandbox_repo() {
  local got
  got="$(sandbox_name_with_owner)" || die "读不到沙箱仓 ${SANDBOX_REPO}"
  [ "$got" = "$SANDBOX_REPO" ] || die "沙箱仓实际是 ${got}，配置是 ${SANDBOX_REPO}"
  [ "$got" != "$SUT_REPO" ] || die "拒绝：沙箱仓不能等于目标仓 ${SUT_REPO}"
}

require_e2e_confirm() {
  if [ "${CESHI_YES:-}" = 1 ]; then
    return 0
  fi
  die "真实 GitHub 测试会改 ${SANDBOX_REPO} 的 ${E2E_BRANCH_PREFIX}* 分支。加上 --yes 或 CESHI_YES=1"
}

e2e_name() {
  local kind="$1"
  printf '%s%s-%s-%s\n' "$E2E_BRANCH_PREFIX" "$kind" "$(date -u +%Y%m%d%H%M%S)" "$$"
}

require_e2e_branch() {
  local br="$1"
  case "$br" in
    "${E2E_BRANCH_PREFIX}"*) ;;
    *) die "拒绝操作非 ${E2E_BRANCH_PREFIX} 分支：$br" ;;
  esac
  branch_ok "$br" || die "非法分支名：$br"
}
