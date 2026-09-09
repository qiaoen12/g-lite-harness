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

sandbox_has_e2e_base() {
  local sha
  sha="$(gh_json api "repos/${SANDBOX_REPO}/git/ref/heads/${SANDBOX_MAIN}" \
    --jq .object.sha 2>/dev/null)" || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]]
}

require_sandbox_repo() {
  local got
  [ "$SUT_REPO" = qiaoen12/g-lite ] \
    || die "目标仓只允许 qiaoen12/g-lite"
  [ "$SUT_MAIN" = main ] || die "目标仓主分支只允许 main"
  [ "$SANDBOX_REPO" = qiaoen12/g-lite-harness ] \
    || die "破坏性 E2E 只允许 qiaoen12/g-lite-harness"
  [ "$SANDBOX_MAIN" = e2e/base ] \
    || die "破坏性 E2E 只允许 squash 进 e2e/base"
  [ "$E2E_BRANCH_PREFIX" = 'e2e/' ] \
    || die "破坏性 E2E 只允许 e2e/* 分支"
  got="$(sandbox_name_with_owner)" || die "读不到沙箱仓 qiaoen12/g-lite-harness"
  [ "$got" = qiaoen12/g-lite-harness ] \
    || die "沙箱仓实际是 ${got}，必须是 qiaoen12/g-lite-harness"
}

require_e2e_confirm() {
  if [ "${CESHI_YES:-}" = 1 ]; then
    return 0
  fi
  die "真实 GitHub 测试会改 ${SANDBOX_REPO} 的 e2e/*（squash 进 e2e/base）。加上 --yes 或 CESHI_YES=1"
}

require_open_human_merge() {
  local json="$1" n="$2" rc=0
  issue_open_human_merge_ok "$json" || rc=$?
  case "$rc" in
    0) return 0 ;;
    1) die "${SUT_REPO}#${n} 不是 OPEN" ;;
    *) die "${SUT_REPO}#${n} 没有 human-merge，拒绝" ;;
  esac
}

sut_open_prs_for_head() {
  local head="$1"
  gh_json pr list --repo "$SUT_REPO" --head "$head" --base "$SUT_MAIN" \
    --state open --json number,url,title,isDraft,headRefOid
}

require_matching_draft_pr() {
  local branch="$1" head="$2" js n draft oid
  js="$(sut_open_prs_for_head "$branch")" || die "读不到 ${SUT_REPO} 的 PR 列表"
  n="$(printf '%s' "$js" | jq 'length')"
  [ "$n" = 1 ] || die "需要恰好一个 head=${branch} base=${SUT_MAIN} 的开放 PR，实际 ${n}"
  draft="$(printf '%s' "$js" | jq -r '.[0].isDraft')"
  [ "$draft" = true ] || die "PR 不是 Draft（isDraft=${draft}），拒绝审查"
  oid="$(printf '%s' "$js" | jq -r '.[0].headRefOid')"
  [ "$oid" = "$head" ] || die "PR headRefOid=${oid} 与 worktree HEAD=${head} 不一致"
  printf '%s' "$js" | jq -c '.[0]'
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
  [ "$br" != "$SANDBOX_MAIN" ] || die "拒绝操作持久 base：${SANDBOX_MAIN}"
  branch_ok "$br" || die "非法分支名：$br"
}
