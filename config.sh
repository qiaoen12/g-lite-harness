# ceshi 默认路径。本机覆盖写 config.local.sh（不进 git）。

SUT_ROOT="${SUT_ROOT:-/Users/qiaoen/Projects2}"
SUT_REPO="${SUT_REPO:-qiaoen12/Project-qiaoen}"
SUT_MAIN="${SUT_MAIN:-main}"
SUT_WORKTREES="${SUT_WORKTREES:-/Users/qiaoen/ceshi-worktrees}"

# 真实 GitHub 破坏性测试只许打这个仓库。
SANDBOX_REPO="${SANDBOX_REPO:-qiaoen12/ceshi}"
SANDBOX_MAIN="${SANDBOX_MAIN:-main}"
E2E_BRANCH_PREFIX="${E2E_BRANCH_PREFIX:-e2e/}"

# G-lite 剩余串行任务（#25）。合入后从队首消失。
G_LITE_QUEUE="${G_LITE_QUEUE:-40 33 30 28 29 31}"
G_LITE_EPIC="${G_LITE_EPIC:-25}"
