# g-lite-harness

Project-qiaoen 的外部控制台和 GitHub 沙箱。

不是把目标仓搬到这里开发。AI 从这里启动，改的是本机 `/Users/qiaoen/Projects2` 的 worktree。

```text
g-lite-harness                控制脚本、提示词、E2E
        │
        ▼
/Users/qiaoen/Projects2       目标仓 main
/Users/qiaoen/ceshi-worktrees 本控制台建的任务树
        │
        ├─ 本地夹具
        ├─ g-lite-harness 上真实 squash / lease / refs
        └─ 目标仓 Draft PR → 审查 → 【停】→ 人 squash merge
```

#40 / #33 已合入。#41 拆成 41a/41b/41c 三个串行 PR，Issue 保持开放直到 41c。

## 命令

```bash
bin/ceshi doctor
bin/ceshi status
bin/ceshi start 41
bin/ceshi test local 41
bin/ceshi test facts --yes
bin/ceshi draft 41 --refs      # 41a / 41b：合入不关 Issue
bin/ceshi draft 41 --fixes     # 41c：final，合入后关 Issue
bin/ceshi review 41
bin/ceshi stop
```

`test facts` / `test zmerge` 在 `qiaoen12/g-lite-harness` 上开临时 `e2e/*` 分支，squash 进 `e2e/base`，不写 `g-lite-harness/main`，也不碰 Project-qiaoen。`test facts` 另开 Refs/Fixes PR，用 GraphQL 关闭引用证明中间 PR 不关 Issue。`SUT_REPO` / `SANDBOX_REPO` / 对应主分支都写死，环境变量改不了。

`start` / `draft` / `review` 要求 Issue 仍是 OPEN 且带 GitHub 标签 `human-merge`。`review` 还要求恰好一个 Draft PR，且 `headRefOid` 等于 worktree HEAD。

`ceshi draft <n>` 默认 `--fixes`。#41a/b 必须 `--refs`。

G-lite 队列默认 `40 33 41 30 42 29 28 31`。改代码前在稳定目标仓 main 上 `0-meta/bin/new task approve <n>`；候选 worktree 不得跑 `new`/`z`。

## 本机覆盖

`config.local.sh`（已忽略）只能改 `SUT_ROOT` 和 `SUT_WORKTREES`。

```bash
SUT_ROOT=/Users/qiaoen/Projects2
SUT_WORKTREES=/Users/qiaoen/ceshi-worktrees
```
