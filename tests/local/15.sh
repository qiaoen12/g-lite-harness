#!/usr/bin/env bash
# Issue #15 local suite：在 Product SUT 上跑 bootstrap 与相关回归。
# 不创建 worktree、不写真实 GitHub、不管理 framework 生命周期。
set -Eeuo pipefail

SUT="${CESHI_SUT:-}"
if [ -z "$SUT" ] && [ -d /Users/qiaoen/ceshi-worktrees/issue-15 ]; then
  SUT=/Users/qiaoen/ceshi-worktrees/issue-15
fi
if [ -z "$SUT" ] || [ ! -d "$SUT/0-meta/lib/new" ]; then
  echo "设置 CESHI_SUT 指向 Issue #15 Product worktree（需含 0-meta/lib/new）" >&2
  exit 2
fi
if [ "$(cd "$SUT" && git rev-parse --show-toplevel)" = /Users/qiaoen/g-lite ]; then
  echo "拒绝在 /Users/qiaoen/g-lite main 工作区跑 #15 local 测试" >&2
  exit 2
fi

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"
LIB="$SUT/0-meta/lib/new"
fail=0
run() {
  local name="$1"
  echo "===== $name ====="
  # 部分 Product 测试用 git rev-parse --show-toplevel 当 ROOT，必须在 SUT 里跑。
  if ! (cd "$SUT" && bash "$LIB/$name"); then
    echo "FAIL $name" >&2
    fail=1
  fi
}

run bootstrap.test.sh
run portable-runtime.test.sh
run claim-resume.test.sh
run agent-card.test.sh
run completion.test.sh
run contract.test.sh
run review.test.sh
run guard-issue14.test.sh
run guard.test.sh

if [ "$fail" -ne 0 ]; then
  echo "bin/ceshi test local 15: FAIL" >&2
  exit 1
fi
echo "bin/ceshi test local 15: PASS"
