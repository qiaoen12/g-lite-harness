# ceshi 子命令。

cmd_doctor() {
  need_cmd git
  need_cmd gh
  need_cmd jq
  need_cmd python3
  echo "控制仓：$CESHI_ROOT"
  echo "目标仓：$SUT_ROOT  ($SUT_REPO)"
  echo "worktree 根：$SUT_WORKTREES"
  echo "沙箱仓：$SANDBOX_REPO"
  [ -d "$SUT_ROOT" ] || die "目标仓目录不存在：$SUT_ROOT"
  [ -d "$SUT_ROOT/.git" ] || [ -f "$SUT_ROOT/.git" ] || die "目标仓不是 git 仓库：$SUT_ROOT"
  sut_git rev-parse --is-inside-work-tree >/dev/null || die "无法读取目标仓"
  local origin
  origin="$(sut_git remote get-url origin)"
  case "$origin" in
    *Project-qiaoen*) ;;
    *) die "目标仓 origin 不是 Project-qiaoen：$origin" ;;
  esac
  gh auth status >/dev/null || die "gh 未登录"
  gh_json repo view "$SUT_REPO" --json nameWithOwner -q .nameWithOwner >/dev/null \
    || die "读不到目标仓 $SUT_REPO"
  require_sandbox_repo
  if sandbox_has_main_commit; then
    echo "沙箱 ${SANDBOX_MAIN}：有提交，可跑 test facts / test zmerge"
  else
    echo "沙箱 ${SANDBOX_MAIN}：还没有提交。先把 ceshi 自己 push 上去，E2E 才能跑。"
  fi
  echo "doctor 通过"
}

g_lite_open_queue() {
  local n state
  for n in $G_LITE_QUEUE; do
    state="$(gh_json issue view "$n" --repo "$SUT_REPO" --json state -q .state 2>/dev/null || true)"
    if [ "$state" = OPEN ]; then
      printf '%s\n' "$n"
    fi
  done
}

cmd_status() {
  cmd_doctor >/dev/null
  echo "G-lite epic：${SUT_REPO}#${G_LITE_EPIC}"
  echo "剩余队列："
  local n title state labels
  for n in $G_LITE_QUEUE; do
    title="$(gh_json issue view "$n" --repo "$SUT_REPO" --json title,state,labels \
      --jq '"\(.state)\t\(.title)\t\([.labels[].name] | join(","))"' 2>/dev/null || true)"
    if [ -z "$title" ]; then
      echo "  #${n}  （读不到）"
      continue
    fi
    echo "  #${n}  $title"
  done
  echo
  echo "下一个未关闭：#$(g_lite_open_queue | awk 'NR==1{print; exit}')"
  echo
  echo "ceshi worktree（改目标仓用这些）："
  worktree_list_ceshi
  echo
  echo "Orca / new 工作树（框架任务不要用）："
  local orca
  orca="$(worktree_list_orca || true)"
  if [ -z "$orca" ]; then
    echo "（无）"
  else
    printf '%s\n' "$orca"
  fi
}

cmd_start() {
  local n="${1:-}" json body branch sparse labels dest
  if [ -z "$n" ]; then
    n="$(g_lite_open_queue | awk 'NR==1{print; exit}')"
    [ -n "$n" ] || die "G-lite 队列没有未关闭 Issue"
  fi
  issue_number_ok "$n" || die "Issue 号不合法：$n"
  cmd_doctor >/dev/null
  json="$(sut_issue_json "$n")" || die "读不到 ${SUT_REPO}#${n}"
  require_open_human_merge "$json" "$n"
  body="$(printf '%s' "$json" | jq -r .body)"
  branch="$(issue_suggested_branch "$body")"
  if [ -z "$branch" ]; then
    branch="meta/issue-${n}"
  fi
  branch_ok "$branch" || die "Issue 建议分支不合法：$branch"
  sparse="$(issue_suggested_sparse "$body")"
  labels="$(sut_issue_labels "$json")"
  worktree_add "$n" "$branch"
  dest="$(worktree_find "$n")"
  mkdir -p "$CESHI_ROOT/records/tasks"
  export CESHI_TPL_ISSUE="$n"
  export CESHI_TPL_SUT_REPO="$SUT_REPO"
  export CESHI_TPL_SUT_ROOT="$SUT_ROOT"
  export CESHI_TPL_CESHI_ROOT="$CESHI_ROOT"
  export CESHI_TPL_WORKTREE="$dest"
  export CESHI_TPL_BRANCH="$branch"
  export CESHI_TPL_TITLE
  CESHI_TPL_TITLE="$(printf '%s' "$json" | jq -r .title)"
  cat > "$CESHI_ROOT/records/tasks/${n}.md" <<EOF
# ${SUT_REPO}#${n}

- 标题：$(printf '%s' "$json" | jq -r .title)
- 状态：$(printf '%s' "$json" | jq -r .state)
- 分支：${branch}
- worktree：${dest}
- sparse 建议：${sparse:-（无，本控制台用完整 worktree）}
- human-merge：$(issue_has_human_merge "$labels" && echo 是 || echo 否)
- 地址：$(printf '%s' "$json" | jq -r .url)

不要在这个任务上跑 new / claim / zdev / zreview / zmerge。
EOF
  echo
  echo "====== 开工卡 ======"
  fill_prompt "$CESHI_ROOT/prompts/start-task.md"
  echo
  echo "Issue 正文："
  echo "----------------------------------------"
  printf '%s\n' "$body"
  echo "----------------------------------------"
  echo
  echo "下一步：cd ${dest}"
  echo "改代码后：ceshi test local ${n} && ceshi test facts --yes && ceshi test zmerge ${n} --yes"
  echo "然后：ceshi draft ${n} && ceshi review ${n} && ceshi stop"
}

cmd_worktree() {
  local sub="${1:-list}" n
  shift || true
  case "$sub" in
    list) worktree_list_ceshi ;;
    add)
      n="${1:-}"
      [ -n "$n" ] || die "用法：ceshi worktree add <Issue号>"
      cmd_start "$n"
      ;;
    remove)
      n="${1:-}"
      [ -n "$n" ] || die "用法：ceshi worktree remove <Issue号>"
      worktree_remove "$n"
      ;;
    *) die "未知 worktree 子命令：$sub" ;;
  esac
}

cmd_draft() {
  local n="${1:-}" wt branch title url json
  issue_number_ok "${n:-}" || die "用法：ceshi draft <Issue号>"
  json="$(sut_issue_json "$n")" || die "读不到 ${SUT_REPO}#${n}"
  require_open_human_merge "$json" "$n"
  wt="$(worktree_find "$n")" || die "先 ceshi start ${n}"
  [ -z "$(git -C "$wt" status --porcelain)" ] || die "工作树不干净：$wt"
  branch="$(worktree_branch "$wt")"
  branch_ok "$branch" || die "当前分支不可交付：$branch"
  git -C "$wt" fetch --quiet origin "refs/heads/${SUT_MAIN}:refs/remotes/origin/${SUT_MAIN}"
  if git -C "$wt" merge-base --is-ancestor HEAD "origin/${SUT_MAIN}"; then
    die "HEAD 已在 origin/${SUT_MAIN} 上，没有可交付提交"
  fi
  title="$(printf '%s' "$json" | jq -r .title)"
  git -C "$wt" push -u origin "HEAD:refs/heads/${branch}"
  url="$(gh_json pr create --repo "$SUT_REPO" --draft \
    --base "$SUT_MAIN" \
    --head "$branch" \
    --title "$title" \
    --body "$(cat <<EOF
## 外部控制台交付

| 项 | 值 |
| --- | --- |
| Issue | ${SUT_REPO}#${n} |
| worktree | \`${wt}\` |
| HEAD | \`$(git -C "$wt" rev-parse HEAD)\` |
| 控制仓 | ceshi |

本 PR 由 ceshi 用 vanilla git + gh 创建。
未走 \`new task\` / claim / zdev / zreview / zmerge。
审查之后必须停，等人确认再 squash merge。

Fixes #${n}
EOF
)")"
  echo "Draft PR：$url"
  echo "下一步：ceshi review ${n} && ceshi stop"
}

cmd_review() {
  local n="${1:-}" wt head title json branch pr pr_num pr_url
  issue_number_ok "${n:-}" || die "用法：ceshi review <Issue号>"
  json="$(sut_issue_json "$n")" || die "读不到 ${SUT_REPO}#${n}"
  require_open_human_merge "$json" "$n"
  wt="$(worktree_find "$n")" || die "先 ceshi start ${n}"
  [ -z "$(git -C "$wt" status --porcelain)" ] || die "工作树不干净：$wt"
  head="$(git -C "$wt" rev-parse HEAD)"
  branch="$(worktree_branch "$wt")"
  pr="$(require_matching_draft_pr "$branch" "$head")"
  pr_num="$(printf '%s' "$pr" | jq -r .number)"
  pr_url="$(printf '%s' "$pr" | jq -r .url)"
  title="$(printf '%s' "$json" | jq -r .title)"
  export CESHI_TPL_ISSUE="$n"
  export CESHI_TPL_SUT_REPO="$SUT_REPO"
  export CESHI_TPL_WORKTREE="$wt"
  export CESHI_TPL_HEAD="$head"
  export CESHI_TPL_TITLE="$title"
  export CESHI_TPL_PR="#${pr_num}"
  export CESHI_TPL_PR_URL="$pr_url"
  echo "====== 审查卡 ======"
  fill_prompt "$CESHI_ROOT/prompts/review.md"
  if [ -n "$wt" ] && [ -x "$wt/0-meta/audit/scripts/check-commit-msg.sh" ] && [ -n "$title" ]; then
    echo
    echo "提交语言（Issue 标题）："
    if "$wt/0-meta/audit/scripts/check-commit-msg.sh" --title "$title" --against "origin/${SUT_MAIN}"; then
      echo "标题通过 check-commit-msg。"
    else
      echo "标题未通过 check-commit-msg。Draft PR 标题必须另写合法 Squash-Title。"
    fi
  fi
  echo
  echo "这不是放行。下一步：ceshi stop"
}

cmd_stop() {
  cat "$CESHI_ROOT/prompts/human-stop.md"
}

cmd_test() {
  local kind="${1:-}" 
  shift || true
  case "$kind" in
    helpers)
      bash "$CESHI_ROOT/tests/helpers/parse.test.sh"
      bash "$CESHI_ROOT/tests/helpers/guard.test.sh"
      ;;
    local) cmd_test_local "$@" ;;
    facts) cmd_test_facts "$@" ;;
    zmerge) cmd_test_zmerge "$@" ;;
    *) die "用法：ceshi test helpers|local|facts|zmerge" ;;
  esac
}

cmd_test_local() {
  local n="${1:-}" wt
  if [ -n "$n" ]; then
    issue_number_ok "$n" || die "Issue 号不合法：$n"
    wt="$(worktree_find "$n")" || die "没有 Issue #${n} 的 worktree"
  else
    wt="$SUT_ROOT"
  fi
  echo "在 ${wt} 跑夹具"
  if [ -f "$wt/.agents/skills/zmerge/scripts/check-mutex-finalize.sh" ]; then
    (cd "$wt" && bash .agents/skills/zmerge/scripts/check-mutex-finalize.sh)
  fi
  if [ -f "$wt/.agents/skills/zmerge/scripts/check-squash-body.sh" ]; then
    (cd "$wt" && bash .agents/skills/zmerge/scripts/check-squash-body.sh)
  fi
  if [ -f "$wt/0-meta/lib/new/claim-resume.test.sh" ]; then
    (cd "$wt" && bash 0-meta/lib/new/claim-resume.test.sh)
  fi
}

take_yes() {
  local a
  for a in "$@"; do
    if [ "$a" = --yes ]; then
      CESHI_YES=1
    fi
  done
}

cmd_test_facts() {
  take_yes "$@"
  require_sandbox_repo
  require_e2e_confirm
  sandbox_has_main_commit || die "沙箱 ${SANDBOX_REPO} 的 ${SANDBOX_MAIN} 还没有提交。先 push ceshi。"
  bash "$CESHI_ROOT/tests/e2e/run.sh" facts
}

cmd_test_zmerge() {
  local n="" a
  for a in "$@"; do
    case "$a" in
      --yes) CESHI_YES=1 ;;
      *) n="$a" ;;
    esac
  done
  require_sandbox_repo
  require_e2e_confirm
  sandbox_has_main_commit || die "沙箱 ${SANDBOX_MAIN} 还没有提交。先 push ceshi。"
  if [ -z "$n" ]; then
    n="$(g_lite_open_queue | awk 'NR==1{print; exit}')"
    n="${n:-40}"
  fi
  CESHI_SUT_CODE="$(sut_code_root "$n")"
  export CESHI_SUT_CODE
  echo "删除函数来自：$CESHI_SUT_CODE"
  echo "范围：zmerge_delete_remote_branch 的真实 GitHub 集成测试，不是完整 zmerge_run。"
  bash "$CESHI_ROOT/tests/e2e/run.sh" zmerge
}

cmd_next() {
  cmd_start
}
