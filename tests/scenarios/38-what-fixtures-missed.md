# #38 夹具没碰到的事

PR #39 合入 #38 时：`check-mutex-finalize.sh` 71 pass，然后 zmerge 把自己 squash 进 main。finalize 要删 `meta/zmerge-finalize-fail-closed-38`，祖先检查失败。

夹具 A3 的准备是：把任务分支 tip 推成已经在 main 历史上的提交。本地 `git merge` 或直接推 main tip 都能做到。GitHub squash 不是这样。

```text
GitHub squash 之后
  PR.headRefOid  = 任务分支 tip（还在）
  mergeCommit    = 一条新的 main 提交
  tip 不是 origin/main 的祖先
```

#38 契约把「tip 已进入 origin/main」写成 `merge-base --is-ancestor`。实现满足契约。夹具验证实现满足契约。真实 squash 第一次出现才炸。

所以 #40 的验收不能只靠再加一条本地夹具。必须先有 `ceshi test facts` 钉住上面三行，再用 `ceshi test zmerge` 打当前 zmerge 代码。
