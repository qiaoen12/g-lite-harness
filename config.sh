# 只允许覆盖本机路径。仓库名和分支由 lib/common.sh 在读完本文件后钉死。

SUT_ROOT="${SUT_ROOT:-/Users/qiaoen/g-lite}"
SUT_WORKTREES="${SUT_WORKTREES:-/Users/qiaoen/ceshi-worktrees}"

# 当前目标仓任务。g-lite#1 是 v1.0 提取；合入后从队首消失。
G_LITE_QUEUE="${G_LITE_QUEUE:-1}"
G_LITE_EPIC="${G_LITE_EPIC:-1}"
