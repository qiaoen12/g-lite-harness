# ceshi 公共函数。由 bin/ceshi 加载，不要单独执行。

set -Eeuo pipefail
export LC_COLLATE=C

CESHI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$CESHI_ROOT/config.sh"
if [ -f "$CESHI_ROOT/config.local.sh" ]; then
  # shellcheck source=/dev/null
  . "$CESHI_ROOT/config.local.sh"
fi

# 仓库身份不可配置。环境变量和 config.local.sh 都不能改。
SUT_REPO="qiaoen12/g-lite"
SUT_MAIN="main"
SANDBOX_REPO="qiaoen12/g-lite-harness"
SANDBOX_MAIN="e2e/base"
E2E_BRANCH_PREFIX="e2e/"

c_ok()   { printf '%s\n' "$*"; }
c_err()  { printf '%s\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "找不到命令：$1"
}

abs_dir() {
  local p="$1"
  [ -d "$p" ] || return 1
  (cd "$p" && pwd -P)
}

fill_prompt() {
  local file="$1"
  python3 -c '
import os, sys
text = open(sys.argv[1], encoding="utf-8").read()
for k, v in os.environ.items():
    if k.startswith("CESHI_TPL_"):
        text = text.replace("{{" + k[len("CESHI_TPL_"):] + "}}", v)
sys.stdout.write(text)
' "$file"
}

usage() {
  cat <<'EOF'
ceshi <命令>

  doctor              检查路径、gh、目标仓、沙箱仓
  status              G-lite 队列、ceshi worktree、禁止使用的 Orca 树
  start [Issue号]     读 qiaoen12/g-lite Issue，建 vanilla worktree
  worktree list
  worktree add <n>    等同 start
  worktree remove <n> 只删本机 ceshi worktree，不删远端
  draft <n> [--refs|--fixes]
                      从 worktree push 并开 Draft PR。
                      --refs 只关联不关 Issue（#41a/b）；默认 --fixes 合入后关 Issue（#41c 与单 PR 任务）
  review <n>          打印审查卡（不是 zreview，不放行合并）
  stop                打印人工停止点
  test helpers        解析器自测，不上网
  test local [n]      在目标 worktree 跑夹具
  test facts          在 qiaoen12/g-lite-harness 上测真实 squash / lease
  test zmerge [n]     真实 GitHub 上测 zmerge_delete_remote_branch（不是完整 zmerge_run）
  next                开工队列里下一个未关闭 Issue

目标仓只许本地改。破坏性 E2E 只 squash 进 qiaoen12/g-lite-harness 的 e2e/base。
EOF
}
