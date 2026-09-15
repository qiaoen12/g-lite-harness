# 定位 Harness 根目录。由 tests/lib/bootstrap.sh 加载，不依赖 cwd。

harness_die() {
  printf '%s\n' "$*" >&2
  exit 1
}

die() { harness_die "$@"; }

harness_usage_die() {
  printf '%s\n' "$*" >&2
  exit 2
}

harness_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || harness_die "找不到必需命令：$1"
}

harness_abs_path() {
  local p="$1"
  [ -n "$p" ] || return 1
  if [ -d "$p" ]; then
    (cd "$p" && pwd)
    return 0
  fi
  if [ -e "$p" ]; then
    local dir base
    dir="$(cd "$(dirname "$p")" && pwd)" || return 1
    base="$(basename "$p")"
    printf '%s/%s\n' "$dir" "$base"
    return 0
  fi
  return 1
}

harness_origin_url() {
  git -C "$1" remote get-url origin 2>/dev/null || true
}

harness_is_harness_origin() {
  local url="$1"
  case "$url" in
    *qiaoen12/g-lite-harness.git*|*qiaoen12/g-lite-harness)
      return 0 ;;
    *) return 1 ;;
  esac
}

harness_is_sut_origin() {
  local url="$1"
  case "$url" in
    *g-lite-harness*) return 1 ;;
    *qiaoen12/g-lite.git*|*qiaoen12/g-lite)
      return 0 ;;
    *) return 1 ;;
  esac
}

harness_verify_root() {
  local root="$1"
  [ -n "$root" ] || harness_die "HARNESS_ROOT 为空"
  [ -d "$root" ] || harness_die "HARNESS_ROOT 不是目录：$root"
  [ -f "$root/tests/run.sh" ] || harness_die "不是 Harness 仓（缺少 tests/run.sh）：$root"
  [ -f "$root/lib/parse.sh" ] || harness_die "不是 Harness 仓（缺少 lib/parse.sh）：$root"
  if [ -d "$root/.git" ] || [ -f "$root/.git" ]; then
    local url
    url="$(harness_origin_url "$root")"
    harness_is_harness_origin "$url" \
      || harness_die "Harness 仓 origin 不是 qiaoen12/g-lite-harness：$url"
  fi
}

harness_head() {
  git -C "$1" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

harness_print_ident() {
  printf 'HARNESS_ROOT=%s\n' "$HARNESS_ROOT"
  printf 'HARNESS_HEAD=%s\n' "$(harness_head "$HARNESS_ROOT")"
  if [ -n "${HARNESS_SUT_SOURCE:-}" ]; then
    printf 'SUT_SOURCE=%s\n' "$HARNESS_SUT_SOURCE"
    printf 'SUT_SOURCE_HEAD=%s\n' "${HARNESS_SUT_SOURCE_HEAD:-unknown}"
  fi
  if [ -n "${HARNESS_SUT:-}" ]; then
    printf 'SUT_WORKDIR=%s\n' "$HARNESS_SUT"
    printf 'SUT_WORKDIR_HEAD=%s\n' "$(harness_head "$HARNESS_SUT")"
  fi
}
