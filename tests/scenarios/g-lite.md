# G-lite 在外部控制台里的排期

来源：https://github.com/qiaoen12/Project-qiaoen/issues/25

已合入：#26 #27 #20 #21 #38。#38 的真实 squash 删分支是坏的，所以先做 #40。

| 序 | Issue | 在本控制台 |
| --- | --- | --- |
| 3b | #40 zmerge squash 等价证明 | `start 40`；`test facts` + `test zmerge` 必须先绿 |
| 4 | #33 删 v1 协议层 | 删除前后各跑一遍同一组夹具 |
| 5 | #30 绊线 + 本地裸仓 | 本机 pre-receive；Action 可在沙箱仓另测 |
| 6 | #28 提示词瘦身 | 量 loaded_bytes，不改门禁语义 |
| 7 | #29 Review 工具化 | zreview 只当辅助 |
| 8 | #31 冻结 ADR | 只文档 |

同一时刻只有一条分支碰目标仓 `0-meta/` / `.agents/`。

全部带 `human-merge`。审查完停。人确认后才人工 squash merge。

这套 new / claim / zdev / zreview / zmerge 在 30 个 business Pilot 之前都算未毕业。Pilot 稳了再减少停止点。
