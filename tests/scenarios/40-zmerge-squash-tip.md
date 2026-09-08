# #40 在本控制台怎么做

Issue：https://github.com/qiaoen12/Project-qiaoen/issues/40

```bash
bin/ceshi start 40
cd /Users/qiaoen/ceshi-worktrees/meta-zmerge-squash-tip-in-main-40
# 只改 .agents/skills/zmerge/
bin/ceshi test local 40
bin/ceshi test facts --yes
bin/ceshi test zmerge 40 --yes
bin/ceshi draft 40
bin/ceshi review 40
bin/ceshi stop
```

`test facts` 必须绿：证明 GitHub squash 后 tip 不在 main 历史上。

`test zmerge` 调用这个 worktree 里的 `zmerge_delete_remote_branch`（覆盖了 `task_branch_pushable` / `z_fetch_origin_main`），对真实 squash 跑 A1–A3。它不是完整 `zmerge_run` E2E：

| 项 | 期望 |
| --- | --- |
| A1 | tip 不在 main 历史上，但 MERGED PR 的 headRefOid 等于 tip、mergeCommit 在 main。删除成功，porcelain=deleted |
| A2 | 同上准备后推新 tip。拒绝删除，新 tip 还在 |
| A3 | tip 已是 main 祖先时删除成功 |
| A4 | PR 已 MERGED 但 mergeCommit 为 null：reason=`z.merge_commit_unobserved`，不删分支，不二次 merge |

当前目标仓 main 的 A1 是红的。这不是测试写错。

`e2e_pr_squash_keep_branch` 在 `gh pr merge --squash` 后立刻读 mergeCommit，GitHub 最终一致下可能为 null。helper 必须有界等待，超时失败，不得把空 oid 交给 A1 当成功。

改代码前在稳定 main：`0-meta/bin/new task approve 40`。不要在候选 worktree 跑 `new task` / claim / zdev / zmerge。Draft PR 之后停，等人 squash merge。
