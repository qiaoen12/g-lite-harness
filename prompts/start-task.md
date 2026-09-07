# 开工 {{SUT_REPO}}#{{ISSUE}}

{{TITLE}}

```text
控制仓：{{CESHI_ROOT}}
目标仓：{{SUT_ROOT}}
本任务 worktree：{{WORKTREE}}
分支：{{BRANCH}}
```

在 worktree 里改代码。不要在 g-lite-harness 里复制目标仓源码。

本阶段框架任务用：

```text
git worktree / commit / push
gh pr create --draft
ceshi test local {{ISSUE}}
ceshi test facts --yes
ceshi test zmerge {{ISSUE}} --yes
ceshi review {{ISSUE}}
ceshi stop
```

不要用：

```text
new task approve
new task grok / codex
claim
zdev / zfix / zsync
zreview（可对照，不放行）
zmerge（禁止）
```

G-lite 到冻结之前，`human-merge` 的任务审查完必须停。
