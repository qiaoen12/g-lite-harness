# 真实 GitHub E2E helper。只打本次拥有的 e2e/*；cleanup 失败不吞掉，也不强删漂移 tip。

E2E_TMP=""
E2E_BRANCHES=""
E2E_PASS=0
E2E_FAIL=0
HARNESS_LEFTOVER=""
HARNESS_CLEANUP_RC=0

e2e_ok() { harness_pass "$*"; E2E_PASS=$((E2E_PASS + 1)); }
e2e_bad() { harness_validation_fail "$*"; E2E_FAIL=$((E2E_FAIL + 1)); }

e2e_expect_eq() {
  if [ "$2" = "$3" ]; then e2e_ok "$1"
  else e2e_bad "$1: 期望 [$2] 实际 [$3]"; fi
}

e2e_expect_true() {
  if eval "$2"; then e2e_ok "$1"
  else e2e_bad "$1"; fi
}

e2e_clone_url() {
  harness_gh repo view "$HARNESS_SANDBOX_REPO" --json sshUrl -q .sshUrl
}

e2e_tip_file() {
  printf '%s/tips/%s\n' "$E2E_TMP" "$(printf '%s' "$1" | tr '/' '_')"
}

e2e_remember_tip() {
  local br="$1" tip="$2"
  harness_require_e2e_branch "$br"
  [ -n "$tip" ] || harness_die "登记 ${br} 时没有 tip"
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

harness_e2e_remote_tip() {
  local wt="$1" br="$2"
  git -C "$wt" ls-remote origin "refs/heads/${br}" | awk '{print $1; exit}'
}

harness_e2e_reject_if_remote_exists() {
  local wt="$1" br="$2" now
  harness_require_e2e_branch "$br"
  now="$(harness_e2e_remote_tip "$wt" "$br")"
  if [ -n "$now" ]; then
    harness_die "远端已有 ${br}（tip=${now}），拒绝覆盖其他运行的对象"
  fi
}

# 精确 lease 删除。tip 漂移返回 2，不强删。分支已不在返回 0。
harness_e2e_delete_owned_branch() {
  local wt="$1" br="$2" tip="$3" now rc=0
  harness_require_e2e_branch "$br"
  [ -n "$tip" ] || return 1
  now="$(harness_e2e_remote_tip "$wt" "$br")"
  if [ -z "$now" ]; then
    return 0
  fi
  if [ "$now" != "$tip" ]; then
    printf 'cleanup: %s tip 漂移 owned=%s remote=%s，不强删\n' "$br" "$tip" "$now" >&2
    printf 'RECOVERY: 若确认仍拥有该对象：git -C "%s" push --force-with-lease="refs/heads/%s:%s" origin ":refs/heads/%s"\n' \
      "$wt" "$br" "$now" "$br" >&2
    return 2
  fi
  git -C "$wt" push --porcelain \
    --force-with-lease="refs/heads/${br}:${tip}" \
    origin ":refs/heads/${br}" || rc=$?
  return "$rc"
}

e2e_setup() {
  harness_need_cmd git
  harness_need_cmd gh
  harness_need_cmd jq
  harness_require_e2e_opt_in
  harness_require_sandbox_repo
  harness_sandbox_has_e2e_base || harness_die "沙箱 ${HARNESS_SANDBOX_REPO}/${HARNESS_SANDBOX_MAIN} 不存在"
  E2E_TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-e2e.XXXXXX")"
  git clone -q "$(e2e_clone_url)" "$E2E_TMP/wt"
  git -C "$E2E_TMP/wt" config user.email e2e@harness.local
  git -C "$E2E_TMP/wt" config user.name harness-e2e
  git -C "$E2E_TMP/wt" config commit.gpgsign false
  git -C "$E2E_TMP/wt" checkout -q "$HARNESS_SANDBOX_MAIN"
  git -C "$E2E_TMP/wt" pull -q --ff-only origin "$HARNESS_SANDBOX_MAIN"
}

e2e_cleanup() {
  local br tip rc leftover="" any=0
  HARNESS_CLEANUP_RC=0
  if [ -n "${E2E_TMP:-}" ] && [ -d "${E2E_TMP}/wt" ]; then
    for br in $E2E_BRANCHES; do
      tip=""
      [ -f "$(e2e_tip_file "$br")" ] && tip="$(cat "$(e2e_tip_file "$br")")"
      if [ -z "$tip" ]; then
        leftover="${leftover} ${br}(no-owned-tip)"
        HARNESS_CLEANUP_RC=1
        continue
      fi
      rc=0
      harness_e2e_delete_owned_branch "$E2E_TMP/wt" "$br" "$tip" || rc=$?
      if [ "$rc" -ne 0 ]; then
        leftover="${leftover} ${br}(rc=${rc})"
        HARNESS_CLEANUP_RC=1
      fi
    done
  fi
  leftover="${leftover# }"
  HARNESS_LEFTOVER="$leftover"
  if [ -n "$leftover" ]; then
    printf 'LEFTOVER branches:%s\n' "$leftover" >&2
    printf '证据目录保留：%s\n' "${E2E_TMP:-（无）}" >&2
    any=1
  fi
  if [ -n "${E2E_TMP:-}" ] && [ -d "$E2E_TMP" ]; then
    if [ "$any" -eq 0 ]; then
      rm -rf "$E2E_TMP"
      E2E_TMP=""
    fi
  fi
  return "$HARNESS_CLEANUP_RC"
}

e2e_on_exit() {
  local test_rc=$?
  local clean_rc=0
  e2e_cleanup || clean_rc=$?
  if [ -n "${HARNESS_EVIDENCE:-}" ]; then
    if ! harness_evidence_write "$HARNESS_EVIDENCE"; then
      printf 'evidence 写入失败：%s\n' "$HARNESS_EVIDENCE" >&2
    fi
  fi
  if [ "$test_rc" -ne 0 ]; then
    exit "$test_rc"
  fi
  if [ "$clean_rc" -ne 0 ]; then
    printf 'cleanup 失败（原测试已通过）。残留：%s\n' "${HARNESS_LEFTOVER:-（见上）}" >&2
    exit 1
  fi
  exit 0
}

e2e_finish() {
  echo "e2e ${E2E_PASS} pass, ${E2E_FAIL} fail"
  harness_finish
}

e2e_push_branch() {
  local wt="$1" br="$2" file="$3"
  harness_require_e2e_branch "$br"
  harness_e2e_reject_if_remote_exists "$wt" "$br"
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
  harness_require_e2e_branch "$br"
  harness_require_write_repo "$HARNESS_SANDBOX_REPO"
  harness_require_squash_base "$HARNESS_SANDBOX_MAIN"
  url="$(GH_PAGER=cat gh pr create --repo "$HARNESS_SANDBOX_REPO" \
    --base "$HARNESS_SANDBOX_MAIN" --head "$br" \
    --title "$title" \
    --body "harness e2e，保留分支以便检查 squash 后 tip。")"
  num="${url##*/}"
  tip="$(git -C "$E2E_TMP/wt" rev-parse HEAD)"
  GH_PAGER=cat gh pr merge "$num" --repo "$HARNESS_SANDBOX_REPO" --squash >/dev/null
  oid=""
  for i in 1 2 3 4 5 6 7 8; do
    json="$(GH_PAGER=cat gh pr view "$num" --repo "$HARNESS_SANDBOX_REPO" \
      --json number,state,headRefOid,mergeCommit)"
    oid="$(printf '%s' "$json" | jq -r '.mergeCommit.oid // empty')"
    if [ -n "$oid" ]; then
      break
    fi
    sleep 1
  done
  [ -n "$oid" ] || harness_die "e2e: ${HARNESS_SANDBOX_REPO}#${num} squash 后 mergeCommit 仍未观察（GitHub 最终一致）。fail-closed，不把空 oid 交给夹具。"
  git -C "$E2E_TMP/wt" fetch -q origin \
    "refs/heads/${HARNESS_SANDBOX_MAIN}:refs/remotes/origin/${HARNESS_SANDBOX_MAIN}"
  printf '%s %s %s\n' "$num" "$tip" "$oid"
}
