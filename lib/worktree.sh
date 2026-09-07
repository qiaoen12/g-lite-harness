# 目标仓的 vanilla git worktree。不走 new worktree / Orca。

sut_git() {
  git -C "$SUT_ROOT" "$@"
}

worktree_root() {
  mkdir -p "$SUT_WORKTREES"
  abs_dir "$SUT_WORKTREES"
}

worktree_path() {
  local n="$1"
  local p
  p="$(worktree_find "$n" || true)"
  if [ -n "$p" ]; then
    printf '%s\n' "$p"
    return 0
  fi
  return 1
}

worktree_find() {
  local n="$1" dir
  dir="$(worktree_root)"
  [ -d "$dir" ] || return 1
  for p in "$dir"/*-"$n" "$dir/issue-$n"; do
    if [ -d "$p/.git" ] || [ -f "$p/.git" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

worktree_branch() {
  local wt="$1"
  git -C "$wt" rev-parse --abbrev-ref HEAD
}

worktree_list_ceshi() {
  local dir
  dir="$(worktree_root)"
  if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null || true)" ]; then
    echo "（没有 ceshi worktree）"
    return 0
  fi
  git -C "$SUT_ROOT" worktree list | awk -v root="$dir" '
    index($1, root) == 1 { print }
  '
}

worktree_list_orca() {
  if [ -d /Users/qiaoen/Projects2-worktrees ]; then
    git -C "$SUT_ROOT" worktree list | awk '
      index($1, "/Users/qiaoen/Projects2-worktrees") == 1 { print }
    '
  fi
}

worktree_add() {
  local n="$1" branch="$2" name dest
  issue_number_ok "$n" || die "Issue 号不合法：$n"
  branch_ok "$branch" || die "分支名不合法：$branch"
  if dest="$(worktree_find "$n")"; then
    echo "已有 worktree：$dest"
    echo "分支：$(worktree_branch "$dest")"
    return 0
  fi
  [ -d "$SUT_ROOT/.git" ] || [ -f "$SUT_ROOT/.git" ] || die "目标仓不存在：$SUT_ROOT"
  sut_git fetch --quiet origin "refs/heads/${SUT_MAIN}:refs/remotes/origin/${SUT_MAIN}" \
    || die "无法 fetch origin/${SUT_MAIN}"
  name="$(worktree_name "$n" "$branch")"
  dest="$(worktree_root)/$name"
  [ ! -e "$dest" ] || die "路径已存在：$dest"
  if sut_git show-ref --verify --quiet "refs/heads/${branch}"; then
    sut_git worktree add "$dest" "$branch"
  elif sut_git ls-remote --exit-code origin "refs/heads/${branch}" >/dev/null 2>&1; then
    sut_git worktree add --track -b "$branch" "$dest" "origin/${branch}"
  else
    sut_git worktree add --no-track -b "$branch" "$dest" "origin/${SUT_MAIN}"
  fi
  echo "worktree：$dest"
  echo "分支：$branch"
}

worktree_remove() {
  local n="$1" dest
  dest="$(worktree_find "$n")" || die "没有 Issue #${n} 的 ceshi worktree"
  if [ -n "$(git -C "$dest" status --porcelain)" ]; then
    die "工作树不干净，拒绝删除：$dest"
  fi
  sut_git worktree remove "$dest"
  echo "已删除本机 worktree：$dest"
  echo "远端分支未动。"
}

sut_code_root() {
  local n="${1:-}" wt
  if [ -n "$n" ] && wt="$(worktree_find "$n")"; then
    printf '%s\n' "$wt"
    return 0
  fi
  printf '%s\n' "$SUT_ROOT"
}
