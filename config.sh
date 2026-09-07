# 只允许覆盖本机路径。仓库名和分支由 lib/common.sh 在读完本文件后钉死。

SUT_ROOT="${SUT_ROOT:-/Users/qiaoen/Projects2}"
SUT_WORKTREES="${SUT_WORKTREES:-/Users/qiaoen/ceshi-worktrees}"

# G-lite 剩余串行任务（#25）。合入后从队首消失。
G_LITE_QUEUE="${G_LITE_QUEUE:-40 33 30 28 29 31}"
G_LITE_EPIC="${G_LITE_EPIC:-25}"
