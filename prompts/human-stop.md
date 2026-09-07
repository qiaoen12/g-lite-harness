# 人工停止点

到这里必须停。

已经允许做的：

- 在 ceshi-worktrees 里改目标仓
- 本地夹具
- 在 qiaoen12/g-lite-harness 上跑真实 squash / lease
- 目标仓 Draft PR
- AI 审查意见

还不能做：

- `zmerge`
- `gh pr merge` 打 Project-qiaoen
- 关 Issue
- 推目标仓 `main`
- 删 `refs/claims/<n>`

人要再看一遍：

1. Issue 契约是不是真实语义，不是夹具语义
2. Review / 本控制台审查意见
3. `ceshi test facts` 和 `ceshi test zmerge` 输出
4. 实际 diff

只有人明确说「可以合并」之后，才用 GitHub 界面或 `gh pr merge --squash` 合目标仓。不要让正在修的 zmerge 合自己。
