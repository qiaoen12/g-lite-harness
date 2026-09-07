# 审查 {{SUT_REPO}}#{{ISSUE}}

这是辅助审查，不是 zreview，也不是合并许可。

```text
worktree：{{WORKTREE}}
HEAD：{{HEAD}}
建议标题：{{TITLE}}
```

对照 Issue 契约逐条看：

1. 契约本身有没有写错真实 Git / GitHub 语义。#38 的祖先检查就是契约先错。
2. 实现是不是只满足了错误契约。
3. 夹具是不是只在本地 bare 仓上复述契约，没碰到 squash。
4. `ceshi test facts` 是否跑过，结果是否和契约一致。
5. `ceshi test zmerge` 是否用**当前 worktree 的代码**打过真实 GitHub。
6. diff 是否超出允许改动范围。
7. 有 `human-merge` 时，审查通过之后必须停。

写完意见后执行 `ceshi stop`。不要 `gh pr merge`。
