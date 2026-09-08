#!/usr/bin/env bash
# 中间 PR 用 Refs，不进入 closingIssuesReferences；final 用 Fixes，会进入。
# GitHub 只对打向默认分支的 PR 填关闭引用，合入默认分支后才真正关 Issue。
# 本测试对默认分支开 Draft、不合入 main，读 GraphQL，并确认 Issue 仍 OPEN。
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
. "$ROOT/lib/parse.sh"
# shellcheck source=/dev/null
. "$ROOT/lib/github.sh"
# shellcheck source=/dev/null
. "$ROOT/tests/e2e/lib.sh"

E2E_ISSUE=""
E2E_PR_REFS=""
E2E_PR_FIXES=""

e2e_closing_numbers() {
  local pr="$1" owner name
  owner="${SANDBOX_REPO%/*}"
  name="${SANDBOX_REPO#*/}"
  GH_PAGER=cat gh api graphql \
    -F owner="$owner" -F name="$name" -F number="$pr" \
    -f query='query($owner:String!,$name:String!,$number:Int!) {
      repository(owner:$owner, name:$name) {
        pullRequest(number:$number) {
          closingIssuesReferences(first: 10) { nodes { number } }
        }
      }
    }' \
    --jq '.data.repository.pullRequest.closingIssuesReferences.nodes[].number // empty' \
    | awk 'NF{print}' | paste -sd, - | tr -d '\n'
}

e2e_refs_cleanup() {
  [ -n "${E2E_PR_REFS:-}" ] && \
    GH_PAGER=cat gh pr close "$E2E_PR_REFS" --repo "$SANDBOX_REPO" >/dev/null 2>&1 || true
  [ -n "${E2E_PR_FIXES:-}" ] && \
    GH_PAGER=cat gh pr close "$E2E_PR_FIXES" --repo "$SANDBOX_REPO" >/dev/null 2>&1 || true
  [ -n "${E2E_ISSUE:-}" ] && \
    GH_PAGER=cat gh issue close "$E2E_ISSUE" --repo "$SANDBOX_REPO" \
      --comment "ceshi e2e cleanup" >/dev/null 2>&1 || true
  e2e_cleanup
}

e2e_push_from_default() {
  local wt="$1" br="$2" file="$3" default="$4"
  require_e2e_branch "$br"
  git -C "$wt" fetch -q origin "refs/heads/${default}:refs/remotes/origin/${default}"
  git -C "$wt" checkout -qb "$br" "origin/${default}"
  mkdir -p "$(dirname "$wt/$file")"
  printf 'e2e %s\n' "$br" > "$wt/$file"
  git -C "$wt" add "$file"
  git -C "$wt" commit -qm "e2e: $br"
  git -C "$wt" push -q origin "HEAD:refs/heads/${br}"
  e2e_register "$br" "$(git -C "$wt" rev-parse HEAD)"
}

trap e2e_refs_cleanup EXIT
e2e_setup

default="$(sandbox_default_branch)"
[ -n "$default" ] || die "读不到沙箱默认分支"
[ "$default" != "$SANDBOX_MAIN" ] || die "默认分支不应是持久 e2e base"

issue_url="$(GH_PAGER=cat gh issue create --repo "$SANDBOX_REPO" \
  --title "e2e refs-fixes $(date -u +%Y%m%d%H%M%S)-$$" \
  --body "ceshi e2e：测 Refs 不关 Issue、Fixes 进入关闭引用。测完即关。")"
E2E_ISSUE="${issue_url##*/}"
[[ "$E2E_ISSUE" =~ ^[1-9][0-9]*$ ]] || die "读不到 e2e Issue 号：$issue_url"

br_refs="$(e2e_name refs)"
e2e_push_from_default "$E2E_TMP/wt" "$br_refs" "e2e-runs/${br_refs}/note.txt" "$default"
refs_body="$(printf 'ceshi e2e intermediate\n\n%s' "$(draft_issue_ref "$E2E_ISSUE" refs)")"
refs_url="$(GH_PAGER=cat gh pr create --repo "$SANDBOX_REPO" --draft \
  --base "$default" --head "$br_refs" \
  --title "e2e refs ${br_refs}" \
  --body "$refs_body")"
E2E_PR_REFS="${refs_url##*/}"

br_fixes="$(e2e_name fixes)"
e2e_push_from_default "$E2E_TMP/wt" "$br_fixes" "e2e-runs/${br_fixes}/note.txt" "$default"
fixes_body="$(printf 'ceshi e2e final\n\n%s' "$(draft_issue_ref "$E2E_ISSUE" fixes)")"
fixes_url="$(GH_PAGER=cat gh pr create --repo "$SANDBOX_REPO" --draft \
  --base "$default" --head "$br_fixes" \
  --title "e2e fixes ${br_fixes}" \
  --body "$fixes_body")"
E2E_PR_FIXES="${fixes_url##*/}"

refs_got="$(e2e_closing_numbers "$E2E_PR_REFS")"
fixes_got="$(e2e_closing_numbers "$E2E_PR_FIXES")"
issue_state="$(GH_PAGER=cat gh issue view "$E2E_ISSUE" --repo "$SANDBOX_REPO" --json state -q .state)"
refs_pr_body="$(GH_PAGER=cat gh pr view "$E2E_PR_REFS" --repo "$SANDBOX_REPO" --json body -q .body)"
fixes_pr_body="$(GH_PAGER=cat gh pr view "$E2E_PR_FIXES" --repo "$SANDBOX_REPO" --json body -q .body)"

e2e_expect_eq "Refs 不进入 closingIssuesReferences" "" "$refs_got"
e2e_expect_eq "Fixes 进入 closingIssuesReferences" "$E2E_ISSUE" "$fixes_got"
e2e_expect_true "Refs PR 正文含 Refs trailer" \
  'printf "%s\n" "$refs_pr_body" | grep -Fxq "Refs #${E2E_ISSUE}"'
e2e_expect_true "Fixes PR 正文含 Fixes trailer" \
  'printf "%s\n" "$fixes_pr_body" | grep -Fxq "Fixes #${E2E_ISSUE}"'
e2e_expect_true "Refs PR 正文无关闭关键字" \
  '! printf "%s\n" "$refs_pr_body" | grep -Eq "^(Fixes|Closes|Resolves) #"'
e2e_expect_eq "未合入默认分支时 Issue 仍 OPEN" OPEN "$issue_state"

e2e_finish
