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

当前目标仓 main 的 A1 是红的。这不是测试写错。

不要 `new task` / claim / zdev / zmerge。Draft PR 之后停，等人 squash merge。
