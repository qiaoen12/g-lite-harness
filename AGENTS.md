# g-lite-harness

外部控制台和 GitHub 测试场。真正改代码的是本机 `qiaoen12/g-lite` clone。

```text
控制仓：/Users/qiaoen/g-lite-harness
目标仓：/Users/qiaoen/g-lite             （qiaoen12/g-lite）
worktree：/Users/qiaoen/ceshi-worktrees
沙箱仓：qiaoen12/g-lite-harness（E2E squash 进 e2e/base，不写 main）
```

## 每次开工先做

```bash
bin/ceshi doctor
bin/ceshi status
bin/ceshi start 1           # 或不写号，取队列下一个 OPEN+human-merge
# 队列：1（g-lite v1.0 提取）
```

然后 `cd` 到打印出来的 worktree，用普通 git 改目标仓。

## 禁止

- 不要用目标仓**候选** runtime 的 `new task approve` / claim / `zdev` / `zreview` / `zmerge` / `zsync` / `zpr` 管理框架自己。g-lite#1 bootstrap 时 main 还没有 runtime，不要强行 approve。
- 不要通过 GitHub API 一行一行改 `qiaoen12/g-lite`。
- 不要在 `/Users/qiaoen/Projects2-worktrees` 里的 Orca 树上做 G-lite。
- 不要把目标仓代码搬进 g-lite-harness。
- 真实 GitHub 破坏性测试只打 `qiaoen12/g-lite-harness` 的 `e2e/*` 分支。

## 允许

```text
git worktree / commit / push
gh pr create --draft          # 41a/b：ceshi draft n --refs；41c / 单 PR：--fixes
bin/ceshi test local|facts|zmerge
AI 审查（本控制台的 review，不是 zreview）
稳定 main 主工作区：0-meta/bin/new task approve <n>
停
人确认后，人工 squash merge
```

`zreview` 可以当辅助对照，不能当放行。`zmerge` 禁止用于框架自己。

## 停

Draft PR 和审查之后必须停。不要 squash merge `qiaoen12/g-lite`。等人看完契约、diff、夹具和 g-lite-harness 真实 GitHub 结果。
