# Issue 正文解析。不要猜缺失字段。

issue_suggested_branch() {
  local body="$1" line
  line="$(printf '%s\n' "$body" | awk '
    $0 ~ /^- 分支[：:]/ {
      if (match($0, /`[^`]+`/)) {
        print substr($0, RSTART+1, RLENGTH-2)
        exit
      }
      if (match($0, /[A-Za-z0-9][A-Za-z0-9._\/-]*/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  ')"
  printf '%s' "$line"
}

issue_suggested_sparse() {
  local body="$1"
  printf '%s\n' "$body" | awk '
    $0 ~ /^- sparse[：:]/ {
      sub(/^- sparse[：:][[:space:]]*/, "")
      gsub(/`/, "")
      print
      exit
    }
  '
}

issue_has_human_merge() {
  local labels="$1"
  printf '%s\n' "$labels" | grep -qx 'human-merge'
}

branch_ok() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || return 1
  [ "$1" != main ] || return 1
  [ "$1" != HEAD ] || return 1
}

worktree_name() {
  local n="$1" branch="$2" slug
  slug="$(printf '%s' "$branch" | tr '/' '-')"
  if [ -n "$slug" ]; then
    printf '%s-%s\n' "$slug" "$n"
  else
    printf 'issue-%s\n' "$n"
  fi
}

issue_number_ok() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}
