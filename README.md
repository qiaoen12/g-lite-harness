# g-lite-harness

`qiaoen12/g-lite` 的外部 GitHub 沙箱。**不是 g-lite 的运行依赖，也不是开发框架。**

日常开发 g-lite 直接使用原生 `git` / `gh`。本仓不管理 Issue、worktree、branch、PR 或 Review。没有 `ceshi` 生命周期 CLI。

## 日常开发 g-lite

在 g-lite 自己的 clone / worktree 里做：

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

不要用 g-lite 的 candidate runtime（`new task` / claim / `zdev` / `zreview` / `zmerge` / `zpr`）管理 framework 自己。

## 本仓只做什么

需要验证真实 GitHub 副作用时，才运行少量叶子脚本。必须显式 `--yes`：

```bash
bash tests/e2e/facts-squash.sh --yes
bash tests/e2e/facts-lease.sh --yes
bash tests/e2e/refs-fixes.sh --yes
bash tests/e2e/zmerge-delete.sh --yes --sut /path/to/g-lite
```

| 脚本 | 为什么必须留在 Harness |
| --- | --- |
| `facts-squash.sh` | GitHub squash 后 tip 不在 `e2e/base` 历史上 |
| `facts-lease.sh` | 远端 `force-with-lease` 与 tip 漂移 |
| `refs-fixes.sh` | `closingIssuesReferences` 是 GitHub 默认分支行为 |
| `zmerge-delete.sh` | 对真实 squash/lease 调用 g-lite 的 `zmerge_delete_remote_branch` |

安全边界写死：

- 只写 `qiaoen12/g-lite-harness`
- 临时分支仅 `e2e/*`
- squash 只进入 `e2e/base`
- 不写 `g-lite` main，不写 consumer，不自动 merge Harness main
- tip 漂移不强删远端分支

`zmerge-delete.sh` 不是完整 `zmerge_run`。SUT 路径必须显式给出。
