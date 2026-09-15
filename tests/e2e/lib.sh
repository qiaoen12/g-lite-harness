# 四个 E2E 叶子脚本共用的克隆 / 登记 / 清理。不是通用测试框架。
# 只打 qiaoen12/g-lite-harness 的 e2e/*，squash 只进 e2e/base。

# 身份写死。环境变量改不了。
SANDBOX_REPO="qiaoen12/g-lite-harness"
SANDBOX_MAIN="e2e/base"
E2E_BRANCH_PREFIX="e2e/"

E2E_TMP=""
E2E_BRANCHES=""
E2E_PASS=0
E2E_FAIL=0

die() { printf '%s\n' "$*" >&2; exit 1; }

e2e_pin_identity() {
  SANDBOX_REPO="qiaoen12/g-lite-harness"
  SANDBOX_MAIN="e2e/base"
  E2E_BRANCH_PREFIX="e2e/"
}

e2e_ok() { E2E_PASS=$((E2E_PASS+1)); printf 'ok  %s\n' "$*"; }
e2e_bad() { E2E_FAIL=$((E2E_FAIL+1)); printf 'not ok  %s\n' "$*" >&2; }

e2e_expect_eq() {
  if [ "$2" = "$3" ]; then e2e_ok "$1"
  else e2e_bad "$1: 期望 [$2] 实际 [$3]"; fi
}

e2e_expect_true() {
  if eval "$2"; then e2e_ok "$1"
  else e2e_bad "$1"; fi
}

e2e_take_yes() {
  local a
  E2E_YES=
  for a in "$@"; do
    if [ "$a" = --yes ]; then
      E2E_YES=1
    fi
  done
  export E2E_YES
}

require_e2e_confirm() {
  if [ "${E2E_YES:-}" = 1 ]; then
    return 0
  fi
  die "真实 GitHub 测试会改 qiaoen12/g-lite-harness 的 e2e/*（squash 进 e2e/base）。加上 --yes"
}

branch_ok() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || return 1
  [ "$1" != main ] || return 1
  [ "$1" != HEAD ] || return 1
}

require_e2e_branch() {
  local br="$1"
  e2e_pin_identity
  case "$br" in
    "${E2E_BRANCH_PREFIX}"*) ;;
    *) die "拒绝操作非 ${E2E_BRANCH_PREFIX} 分支：${br}" ;;
  esac
  [ "$br" != "$SANDBOX_MAIN" ] || die "拒绝操作持久 base：${SANDBOX_MAIN}"
  branch_ok "$br" || die "非法分支名：${br}"
}

sandbox_name_with_owner() {
  GH_PAGER=cat gh repo view "$SANDBOX_REPO" --json nameWithOwner -q .nameWithOwner
}

sandbox_default_branch() {
  GH_PAGER=cat gh repo view "$SANDBOX_REPO" --json defaultBranchRef \
    -q .defaultBranchRef.name
}

sandbox_has_e2e_base() {
  local sha
  sha="$(GH_PAGER=cat gh api "repos/${SANDBOX_REPO}/git/ref/heads/${SANDBOX_MAIN}" \
    --jq .object.sha 2>/dev/null)" || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]]
}

require_sandbox_repo() {
  local got
  e2e_pin_identity
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

e2e_name() {
  local kind="$1"
  printf '%s%s-%s-%s\n' "$E2E_BRANCH_PREFIX" "$kind" "$(date -u +%Y%m%d%H%M%S)" "$$"
}

e2e_clone_url() {
  gh repo view "$SANDBOX_REPO" --json sshUrl -q .sshUrl
}

e2e_setup() {
  command -v git >/dev/null 2>&1 || die "找不到 git"
  command -v gh >/dev/null 2>&1 || die "找不到 gh"
  command -v jq >/dev/null 2>&1 || die "找不到 jq"
  e2e_pin_identity
  require_e2e_confirm
  require_sandbox_repo
  sandbox_has_e2e_base || die "沙箱 ${SANDBOX_REPO}/${SANDBOX_MAIN} 不存在"
  E2E_TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-e2e.XXXXXX")"
  git clone -q "$(e2e_clone_url)" "$E2E_TMP/wt"
  git -C "$E2E_TMP/wt" config user.email e2e@harness.local
  git -C "$E2E_TMP/wt" config user.name harness-e2e
  git -C "$E2E_TMP/wt" config commit.gpgsign false
  git -C "$E2E_TMP/wt" checkout -q "$SANDBOX_MAIN"
  git -C "$E2E_TMP/wt" pull -q --ff-only origin "$SANDBOX_MAIN"
}

e2e_tip_file() {
  printf '%s/tips/%s\n' "$E2E_TMP" "$(printf '%s' "$1" | tr '/' '_')"
}

e2e_remember_tip() {
  local br="$1" tip="$2"
  require_e2e_branch "$br"
  [ -n "$tip" ] || die "登记 ${br} 时没有 tip"
  mkdir -p "$E2E_TMP/tips"
  printf '%s\n' "$tip" >"$(e2e_tip_file "$br")"
  case " $E2E_BRANCHES " in
    *" $br "*) ;;
    *) E2E_BRANCHES="$E2E_BRANCHES $br" ;;
  esac
}

e2e_register() {
  local br="$1" tip="${2:-}"
  if [ -z "$tip" ]; then
    tip="$(git -C "$E2E_TMP/wt" ls-remote origin "refs/heads/${br}" | awk '{print $1; exit}')"
  fi
  e2e_remember_tip "$br" "$tip"
}

e2e_forget() {
  local br="$1" out="" x
  for x in $E2E_BRANCHES; do
    [ "$x" = "$br" ] || out="$out $x"
  done
  E2E_BRANCHES="${out# }"
}

e2e_remote_tip() {
  git -C "$1" ls-remote origin "refs/heads/${2}" | awk '{print $1; exit}'
}

e2e_refuse_existing() {
  local wt="$1" br="$2" now
  require_e2e_branch "$br"
  now="$(e2e_remote_tip "$wt" "$br")"
  if [ -n "$now" ]; then
    die "远端已有 ${br}（tip=${now}），拒绝覆盖"
  fi
}

# 精确 lease。tip 漂移不强删，返回 2。
e2e_delete_owned() {
  local wt="$1" br="$2" tip="$3" now rc=0
  require_e2e_branch "$br"
  [ -n "$tip" ] || return 1
  now="$(e2e_remote_tip "$wt" "$br")"
  if [ -z "$now" ]; then
    return 0
  fi
  if [ "$now" != "$tip" ]; then
    printf 'cleanup: %s tip 漂移 owned=%s remote=%s，不强删\n' "$br" "$tip" "$now" >&2
    printf 'RECOVERY: git -C "%s" push --force-with-lease="refs/heads/%s:%s" origin ":refs/heads/%s"\n' \
      "$wt" "$br" "$now" "$br" >&2
    return 2
  fi
  git -C "$wt" push --porcelain \
    --force-with-lease="refs/heads/${br}:${tip}" \
    origin ":refs/heads/${br}" || rc=$?
  return "$rc"
}

e2e_cleanup() {
  local br tip rc leftover=""
  if [ -n "${E2E_TMP:-}" ] && [ -d "${E2E_TMP}/wt" ]; then
    for br in $E2E_BRANCHES; do
      tip=""
      [ -f "$(e2e_tip_file "$br")" ] && tip="$(cat "$(e2e_tip_file "$br")")"
      if [ -z "$tip" ]; then
        leftover="${leftover} ${br}"
        continue
      fi
      rc=0
      e2e_delete_owned "$E2E_TMP/wt" "$br" "$tip" || rc=$?
      if [ "$rc" -ne 0 ]; then
        leftover="${leftover} ${br}"
      fi
    done
  fi
  leftover="${leftover# }"
  if [ -n "$leftover" ]; then
    printf 'LEFTOVER branches: %s\n' "$leftover" >&2
    printf '证据目录保留：%s\n' "${E2E_TMP:-}" >&2
    return 1
  fi
  if [ -n "${E2E_TMP:-}" ] && [ -d "$E2E_TMP" ]; then
    rm -rf "$E2E_TMP"
    E2E_TMP=""
  fi
  return 0
}

e2e_finish() {
  echo "e2e ${E2E_PASS} pass, ${E2E_FAIL} fail"
  [ "$E2E_FAIL" = 0 ]
}

e2e_push_branch() {
  local wt="$1" br="$2" file="$3"
  require_e2e_branch "$br"
  e2e_refuse_existing "$wt" "$br"
  git -C "$wt" checkout -qb "$br"
  mkdir -p "$(dirname "$wt/$file")"
  printf 'e2e %s\n' "$br" >"$wt/$file"
  git -C "$wt" add "$file"
  git -C "$wt" commit -qm "e2e: $br"
  git -C "$wt" push -q origin "HEAD:refs/heads/${br}"
  e2e_register "$br" "$(git -C "$wt" rev-parse HEAD)"
}

e2e_pr_squash_keep_branch() {
  local br="$1" title="$2" url num tip json oid i
  require_e2e_branch "$br"
  e2e_pin_identity
  [ "$SANDBOX_REPO" = qiaoen12/g-lite-harness ] || die "squash 只允许 qiaoen12/g-lite-harness"
  [ "$SANDBOX_MAIN" = e2e/base ] || die "squash 只允许进入 e2e/base"
  url="$(GH_PAGER=cat gh pr create --repo "$SANDBOX_REPO" \
    --base "$SANDBOX_MAIN" --head "$br" \
    --title "$title" \
    --body "harness e2e，保留分支以便检查 squash 后 tip。")"
  num="${url##*/}"
  tip="$(git -C "$E2E_TMP/wt" rev-parse HEAD)"
  GH_PAGER=cat gh pr merge "$num" --repo "$SANDBOX_REPO" --squash >/dev/null
  oid=""
  for i in 1 2 3 4 5 6 7 8; do
    json="$(GH_PAGER=cat gh pr view "$num" --repo "$SANDBOX_REPO" \
      --json number,state,headRefOid,mergeCommit)"
    oid="$(printf '%s' "$json" | jq -r '.mergeCommit.oid // empty')"
    if [ -n "$oid" ]; then
      break
    fi
    sleep 1
  done
  [ -n "$oid" ] || die "e2e: ${SANDBOX_REPO}#${num} squash 后 mergeCommit 仍未观察。fail-closed。"
  git -C "$E2E_TMP/wt" fetch -q origin \
    "refs/heads/${SANDBOX_MAIN}:refs/remotes/origin/${SANDBOX_MAIN}"
  printf '%s %s %s\n' "$num" "$tip" "$oid"
}
