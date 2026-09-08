# G-lite 在外部控制台里的排期

来源：https://github.com/qiaoen12/Project-qiaoen/issues/25

已合入：#26 #27 #20 #21 #38 #40 #33。

队列（与 `config.sh` / #25 一致；已关闭的号会被 `status` 跳过）：

```text
40 33 41 30 42 29 28 31
```

下一个未关闭：#41。

| 序 | Issue | 在本控制台 |
| --- | --- | --- |
| 3b | #40 zmerge squash 等价证明 | 已合入。`test facts` + `test zmerge` 是 squash 后 tip 不在历史上的基线。 |
| 4 | #33 删 v1 协议层 | 已合入。`test local 33` 跑 `contract.test.sh` 与 `new check --tier commit`。 |
| 5 | #41 Portable Runtime | 三个串行 PR：41a bind/z_load、41b claim+canonical z、41c setup。Issue 保持 OPEN 直到 41c。 |
| 6 | #30 绊线 + 本地裸仓 | 本机 pre-receive；镜像 GitHub 再判定；lease/删除必须转发 |
| 7 | #42 metrics reliability | `test local 42` 跑 `metrics.test.sh`；zfix 不得记成 zdev.* |
| 8 | #29 Review / Actor | zreview 只当辅助；Self-review 必须能被 zmerge 读到 |
| 9 | #28 提示词瘦身 | 量 loaded_bytes；start card 取代阅读 |
| 10 | #31 冻结 ADR | 只文档；冻结 canonical runtime，不是整棵 `.agents/` |

#41 三次 Draft 的关联关键字：

```text
ceshi draft 41 --refs     # 41a / 41b：合入不关 Issue
ceshi draft 41 --fixes    # 41c：final，合入默认分支后关 Issue
```

`ceshi draft <n>` 默认 `--fixes`（单 PR 任务）。中间 PR 不得写 `Fixes`。`test facts` 含 Refs/Fixes 的真实 GitHub 关闭引用。

每个工作 Issue 改代码前，在稳定 `/Users/qiaoen/Projects2` main 上 `0-meta/bin/new task approve <n>`。禁令对象是候选 runtime，不是稳定 CLI。

`ceshi test local`：#41 跑 zmerge/claim 夹具 + `contract.test.sh` + `new check --tier commit`。#42 追加 metrics.test.sh。

同一时刻只有一条分支碰目标仓 `0-meta/` / `.agents/`。

全部带 GitHub 标签 `human-merge`。审查完停。人确认后才人工 squash merge。

这套 new / claim / zdev / zreview / zmerge 在 30 个 business Pilot 之前都算未毕业。Pilot 稳了再减少停止点。
