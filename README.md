# ceshi

Project-qiaoen 的外部控制台和 GitHub 沙箱。

不是把目标仓搬到这里开发。AI 从这里启动，改的是本机 `/Users/qiaoen/Projects2` 的 worktree。

```text
ceshi                         控制脚本、提示词、E2E
        │
        ▼
/Users/qiaoen/Projects2       目标仓 main
/Users/qiaoen/ceshi-worktrees 本控制台建的任务树
        │
        ├─ 本地夹具
        ├─ ceshi 上真实 squash / lease / refs
        └─ 目标仓 Draft PR → 审查 → 【停】→ 人 squash merge
```

#38 合进去之后 finalize 卡在删分支，就是因为夹具用本地 bare 仓模拟「tip 已在 main 上」，没碰到 GitHub squash 之后 tip 不在 main 历史上这件事。#40 要先在 ceshi 上看到真实语义，再给目标仓开 Draft PR。

## 命令

```bash
bin/ceshi doctor
bin/ceshi status
bin/ceshi start 40
bin/ceshi test local 40
bin/ceshi test facts --yes
bin/ceshi test zmerge 40 --yes
bin/ceshi draft 40
bin/ceshi review 40
bin/ceshi stop
```

`test facts` 会在 `qiaoen12/ceshi` 上开 `e2e/*` 分支、PR、squash。`test zmerge` 只集成测试 `zmerge_delete_remote_branch`，不是完整 `zmerge_run`。两者都不会碰 Project-qiaoen 的分支。沙箱仓写死为 `qiaoen12/ceshi`，环境变量改不了。

`start` / `draft` / `review` 要求 Issue 仍是 OPEN 且带 `human-merge`。`review` 还要求恰好一个 Draft PR，且 `headRefOid` 等于 worktree HEAD。

## 本机覆盖

`config.local.sh`（已忽略）只能改目标仓路径。不能改沙箱仓。

```bash
SUT_ROOT=/Users/qiaoen/Projects2
SUT_WORKTREES=/Users/qiaoen/ceshi-worktrees
```
