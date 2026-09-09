# g-lite-harness

`qiaoen12/g-lite` 的外部控制台和 GitHub 沙箱。不是生产依赖。

不是把目标仓搬到这里开发。AI 从这里启动，改的是本机 `/Users/qiaoen/g-lite` 的 worktree。

```text
g-lite-harness                控制脚本、提示词、E2E
        │
        ▼
/Users/qiaoen/g-lite          目标仓 main（qiaoen12/g-lite）
/Users/qiaoen/ceshi-worktrees 本控制台建的任务树
        │
        ├─ 本地夹具
        ├─ g-lite-harness 上真实 squash / lease / refs
        └─ 目标仓 Draft PR → 审查 → 【停】→ 人 squash merge
```

当前队列：`g-lite#1`（从 Project-qiaoen Freeze SHA 提取 v1.0 candidate）。

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

`test facts` / `test zmerge` 在 `qiaoen12/g-lite-harness` 上开临时 `e2e/*` 分支，squash 进 `e2e/base`，不写 `g-lite-harness/main`，也不碰 `qiaoen12/g-lite` 的 main。`test facts` 另开 Refs/Fixes PR，用 GraphQL 关闭引用证明中间 PR 不关 Issue。`SUT_REPO` / `SANDBOX_REPO` / 对应主分支都写死，环境变量改不了。

`start` / `draft` / `review` 要求 Issue 仍是 OPEN 且带 GitHub 标签 `human-merge`。`review` 还要求恰好一个 Draft PR，且 `headRefOid` 等于 worktree HEAD。

`ceshi draft <n>` 默认 `--fixes`。#41a/b 必须 `--refs`。

G-lite 队列默认 `1`。g-lite#1 bootstrap 时 main 还没有 runtime，不要跑 `new task approve`。候选 worktree 不得用候选 runtime 给自己 claim / review / merge。

## 本机覆盖

`config.local.sh`（已忽略）只能改 `SUT_ROOT` 和 `SUT_WORKTREES`。

```bash
SUT_ROOT=/Users/qiaoen/g-lite
SUT_WORKTREES=/Users/qiaoen/ceshi-worktrees
```
