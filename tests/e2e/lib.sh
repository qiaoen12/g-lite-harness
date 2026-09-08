# 真实 GitHub E2E 公共函数。只打 SANDBOX_REPO。

E2E_TMP=""
E2E_BRANCHES=""
E2E_PASS=0
E2E_FAIL=0

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

e2e_clone_url() {
  gh repo view "$SANDBOX_REPO" --json sshUrl -q .sshUrl
}

e2e_setup() {
  require_sandbox_repo
  E2E_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ceshi-e2e.XXXXXX")"
  git clone -q "$(e2e_clone_url)" "$E2E_TMP/wt"
  git -C "$E2E_TMP/wt" config user.email e2e@ceshi.local
  git -C "$E2E_TMP/wt" config user.name ceshi-e2e
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
  printf '%s\n' "$tip" > "$(e2e_tip_file "$br")"
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

e2e_cleanup() {
  local br tip
  if [ -n "${E2E_TMP:-}" ] && [ -d "${E2E_TMP}/wt" ]; then
    for br in $E2E_BRANCHES; do
      tip=""
      [ -f "$(e2e_tip_file "$br")" ] && tip="$(cat "$(e2e_tip_file "$br")")"
      [ -n "$tip" ] || continue
      git -C "$E2E_TMP/wt" push --quiet --porcelain \
        --force-with-lease="refs/heads/${br}:${tip}" \
        origin ":refs/heads/${br}" 2>/dev/null || true
    done
  fi
  if [ -n "${E2E_TMP:-}" ] && [ -d "$E2E_TMP" ]; then
    rm -rf "$E2E_TMP"
  fi
}

e2e_finish() {
  echo "e2e ${E2E_PASS} pass, ${E2E_FAIL} fail"
  [ "$E2E_FAIL" = 0 ]
}

e2e_push_branch() {
  local wt="$1" br="$2" file="$3"
  require_e2e_branch "$br"
  git -C "$wt" checkout -qb "$br"
  mkdir -p "$(dirname "$wt/$file")"
  printf 'e2e %s\n' "$br" > "$wt/$file"
  git -C "$wt" add "$file"
  git -C "$wt" commit -qm "e2e: $br"
  git -C "$wt" push -q origin "HEAD:refs/heads/${br}"
  e2e_register "$br" "$(git -C "$wt" rev-parse HEAD)"
}

e2e_pr_squash_keep_branch() {
  local br="$1" title="$2" url num tip json oid i
  url="$(GH_PAGER=cat gh pr create --repo "$SANDBOX_REPO" \
    --base "$SANDBOX_MAIN" --head "$br" \
    --title "$title" \
    --body "ceshi e2e，保留分支以便检查 squash 后 tip。")"
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
  [ -n "$oid" ] || die "e2e: ${SANDBOX_REPO}#${num} squash 后 mergeCommit 仍未观察（GitHub 最终一致）。fail-closed，不把空 oid 交给夹具。"
  git -C "$E2E_TMP/wt" fetch -q origin \
    "refs/heads/${SANDBOX_MAIN}:refs/remotes/origin/${SANDBOX_MAIN}"
  printf '%s %s %s\n' "$num" "$tip" "$oid"
}
