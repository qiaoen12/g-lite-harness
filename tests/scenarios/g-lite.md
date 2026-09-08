# G-lite 在外部控制台里的排期

来源：https://github.com/qiaoen12/Project-qiaoen/issues/25

已合入：#26 #27 #20 #21 #38。#38 的真实 squash 删分支是坏的，所以先做 #40。

队列（与 `config.sh` / #25 一致）：

```text
40 33 41 30 42 29 28 31
```

| 序 | Issue | 在本控制台 |
| --- | --- | --- |
| 3b | #40 zmerge squash 等价证明 | `start 40`；`test facts` + `test zmerge` 必须先绿；含 mergeCommit 未观察 |
| 4 | #33 删 v1 协议层 | `test local 33` 必须跑 `contract.test.sh` 与 `new check --tier commit`；先修 4 条陈旧断言到 166/166 |
| 5 | #41 Portable Runtime | 三个串行 PR：41a bind/z_load、41b claim+canonical z、41c setup |
| 6 | #30 绊线 + 本地裸仓 | 本机 pre-receive；镜像 GitHub 再判定；lease/删除必须转发 |
| 7 | #42 metrics reliability | `test local 42` 跑 `metrics.test.sh`；zfix 不得记成 zdev.* |
| 8 | #29 Review / Actor | zreview 只当辅助；Self-review 必须能被 zmerge 读到 |
| 9 | #28 提示词瘦身 | 量 loaded_bytes；start card 取代阅读 |
| 10 | #31 冻结 ADR | 只文档；冻结 canonical runtime，不是整棵 `.agents/` |

每个工作 Issue 改代码前，在稳定 `/Users/qiaoen/Projects2` main 上 `0-meta/bin/new task approve <n>`。禁令对象是候选 runtime，不是稳定 CLI。

`ceshi test local`：#40 只跑既有 zmerge/claim 夹具（main 上 `contract.test.sh` 仍 162/4，留给 #33）。#33/#41 追加 contract + `new check --tier commit`。#42 追加 metrics.test.sh。

同一时刻只有一条分支碰目标仓 `0-meta/` / `.agents/`。

全部带 GitHub 标签 `human-merge`。审查完停。人确认后才人工 squash merge。

这套 new / claim / zdev / zreview / zmerge 在 30 个 business Pilot 之前都算未毕业。Pilot 稳了再减少停止点。
