# Issue 26 验证记录

Harness candidate：`harness/issue-26` worktree `/Users/qiaoen/g-lite-harness-worktrees/issue-26`。
记录时 HEAD 仍为分支起点 `e5e5b4865aa43a02c3989af169ef7a45cb9322a8`（提交前）。合入前以 Draft PR 的最终 HEAD 为准。

外部 SUT：`/Users/qiaoen/g-lite` @ `4fdd3530b565faa73304735779689a494f1862d6`（隔离副本，源 checkout 未改）。

| 项 | 环境 | 结果 |
| --- | --- | --- |
| `tests/run.sh selfcheck` | 本地 | PASS（helpers / result / dispatch / sandbox-local） |
| 非仓库 cwd、空格路径、未知场景、缺 `--sut` | 本地 | 明确失败，无零项成功 |
| `local --scenario squash-body --sut /Users/qiaoen/g-lite` | 隔离副本 | PASS；源 HEAD 不变 |
| `facts --yes` | 真实 GitHub `e2e/*` | squash 6、lease 3、Refs-Fixes 6；对象已清理。临时 Issue/PR：#30/#31/#32 已关，未合入 main |
| `zmerge-delete --sut /Users/qiaoen/g-lite --yes` | 真实 GitHub + 隔离 SUT | A1/A2/A3 共 8 PASS；只验 `zmerge_delete_remote_branch` |
| 缺 `--yes` 的叶子脚本 | 本地 | 写入前拒绝 |

未验证：未在其它机器/其它 gh 账号上重复；未跑完整 `zmerge_run`（本任务不承诺）。
