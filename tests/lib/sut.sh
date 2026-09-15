# 被测输入（SUT）。必须显式路径，不从 Issue 队列、task 记录或目录后缀推导。

harness_git_head() {
  git -C "$1" rev-parse HEAD
}

harness_git_porcelain() {
  git -C "$1" status --porcelain
}

harness_verify_sut() {
  local p="$1" url
  [ -n "$p" ] || harness_die "缺少 --sut PATH。禁止 fallback 到 g-lite main 或 worktree 队列。"
  [ -d "$p" ] || harness_die "SUT 路径不存在：$p"
  [ -d "$p/.git" ] || [ -f "$p/.git" ] || harness_die "SUT 不是 git 仓库：$p"
  git -C "$p" rev-parse --is-inside-work-tree >/dev/null \
    || harness_die "无法读取 SUT：$p"
  if [ -f "$p/.harness-sut-fixture" ]; then
    return 0
  fi
  url="$(harness_origin_url "$p")"
  harness_is_sut_origin "$url" \
    || harness_die "SUT origin 不是 qiaoen12/g-lite（且无 .harness-sut-fixture）：$url"
}

harness_refuse_inplace_user_tree() {
  local p="$1" abs tmp
  abs="$(harness_abs_path "$p")" || harness_die "无法解析路径：$p"
  if [ -f "$abs/.harness-sut-fixture" ]; then
    return 0
  fi
  tmp="${TMPDIR:-/tmp}"
  case "$abs" in
    "$tmp"/*|/tmp/*)
      return 0 ;;
  esac
  harness_die "拒绝在用户现有工作树原地跑有副作用的测试：${abs}。使用默认 --isolate，或只对临时/fixture 副本使用 --no-isolate。"
}

harness_sut_isolate() {
  local src="$1" dest="$2" head url
  [ ! -e "$dest" ] || harness_die "隔离目录已存在，拒绝覆盖：$dest"
  head="$(harness_git_head "$src")"
  git clone --quiet --local "$src" "$dest" \
    || harness_die "无法隔离复制 SUT：$src -> $dest"
  git -C "$dest" checkout --quiet "$head"
  url="$(harness_origin_url "$src")"
  if [ -n "$url" ]; then
    git -C "$dest" remote set-url origin "$url"
  fi
  if [ -f "$src/.harness-sut-fixture" ]; then
    cp "$src/.harness-sut-fixture" "$dest/.harness-sut-fixture"
  fi
  git -C "$dest" config user.email harness-test@local
  git -C "$dest" config user.name harness-test
  git -C "$dest" config commit.gpgsign false
  printf '%s\n' "$head"
}

harness_prepare_sut() {
  local src="$1" isolate="$2" workdir="${3:-}"
  local abs dest source_head source_porcelain run_head
  abs="$(harness_abs_path "$src")" || harness_die "SUT 路径不存在：$src"
  harness_verify_sut "$abs"
  source_head="$(harness_git_head "$abs")"
  source_porcelain="$(harness_git_porcelain "$abs")"
  HARNESS_SUT_SOURCE="$abs"
  HARNESS_SUT_SOURCE_HEAD="$source_head"
  HARNESS_SUT_SOURCE_PORCELAIN="$source_porcelain"
  if [ "$isolate" = 1 ]; then
    if [ -n "$workdir" ]; then
      mkdir -p "$workdir"
      dest="$workdir/sut"
    else
      dest="$(mktemp -d "${TMPDIR:-/tmp}/harness-sut.XXXXXX")/sut"
    fi
    harness_sut_isolate "$abs" "$dest" >/dev/null
    HARNESS_SUT="$dest"
    HARNESS_SUT_ISOLATE=1
  else
    harness_refuse_inplace_user_tree "$abs"
    if [ -n "$workdir" ]; then
      HARNESS_SUT="$(harness_abs_path "$workdir")" || harness_die "workdir 不存在：$workdir"
    else
      HARNESS_SUT="$abs"
    fi
    HARNESS_SUT_ISOLATE=0
  fi
  run_head="$(harness_git_head "$HARNESS_SUT")"
  [ "$run_head" = "$source_head" ] \
    || harness_die "隔离副本 HEAD 与源不一致 source=${source_head} workdir=${run_head}"
}

harness_assert_source_unchanged() {
  local now_head now_porc
  [ -n "${HARNESS_SUT_SOURCE:-}" ] || return 0
  now_head="$(harness_git_head "$HARNESS_SUT_SOURCE")"
  now_porc="$(harness_git_porcelain "$HARNESS_SUT_SOURCE")"
  [ "$now_head" = "$HARNESS_SUT_SOURCE_HEAD" ] \
    || harness_die "SUT 源 HEAD 被改动：${HARNESS_SUT_SOURCE_HEAD} -> ${now_head}"
  [ "$now_porc" = "$HARNESS_SUT_SOURCE_PORCELAIN" ] \
    || harness_die "SUT 源工作区被改动：$HARNESS_SUT_SOURCE"
}

harness_mk_git_repo() {
  local d="$1" origin="${2:-https://github.com/qiaoen12/g-lite.git}"
  mkdir -p "$d"
  git -C "$d" init --quiet
  git -C "$d" config user.email harness-fixture@local
  git -C "$d" config user.name harness-fixture
  git -C "$d" config commit.gpgsign false
  git -C "$d" remote add origin "$origin"
  printf 'fixture\n' >"$d/README"
  git -C "$d" add README
  git -C "$d" commit --quiet -m init
  : >"$d/.harness-sut-fixture"
}
