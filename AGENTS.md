# g-lite-harness

外部 GitHub 沙箱，不是 g-lite 的运行依赖，也不是开发框架。

日常开发 g-lite 直接使用原生 `git` / `gh`。本仓不管理 Issue / worktree / branch / PR / Review。不要从这里启动 g-lite 开发。

`bin/ceshi test local <n>` 只调度本仓 `tests/local/<n>.sh`，不是生命周期 CLI。不要用它 start / claim / review / merge。

## 正常开发流程

在 g-lite 自己的 clone / worktree：

```text
fetch origin/main
→ git worktree add
→ Agent 开发
→ g-lite 自身测试
→ git add / commit
→ committed + clean
→ 新独立 Agent Review
→ git push
→ gh pr create --draft
→ STOP
→ human squash merge
```

不要用 g-lite candidate runtime（`new task` / claim / `zdev` / `zreview` / `zmerge` / `zpr`）管理 framework 自己。

## 本仓

只在明确需要真实 GitHub 副作用时运行：

```bash
bash tests/e2e/facts-squash.sh --yes
bash tests/e2e/facts-lease.sh --yes
bash tests/e2e/refs-fixes.sh --yes
bash tests/e2e/zmerge-delete.sh --yes --sut /path/to/g-lite
```

只写 `qiaoen12/g-lite-harness` 的 `e2e/*`，squash 只进 `e2e/base`。不写 g-lite main，不 merge Harness main。Draft PR 和审查之后 STOP，由人 squash merge。
