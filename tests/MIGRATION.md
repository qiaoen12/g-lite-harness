# 旧测试入口 → 新命令

旧入口仍可通过 `bin/ceshi test …` 转到 `tests/run.sh`，但不再从 Issue 队列、task 记录或 worktree 名推导 SUT。`a55c90f` / `e5e5b48` 增加的 #13 completion 与 #14 guard-recovery 覆盖保留为 suite `13` / `14`。

| 旧命令 | 新命令 | 保留覆盖 |
| --- | --- | --- |
| `ceshi test helpers` | `tests/run.sh helpers` | parse + common 身份钉死 + tests/lib 身份钉死 |
| （无，本任务新增） | `tests/run.sh result` | 成功 / 断言失败 / 缺程序 / 非零无输出 / 管道 / 缺必需 / cleanup |
| （无，本任务新增） | `tests/run.sh dispatch` | 非仓库 cwd、空格路径、未知场景、错误 SUT |
| （无，本任务新增） | `tests/run.sh sandbox-local` | 错误 repo/base、缺 opt-in、已有对象、tip 漂移 |
| （无，本任务新增） | `tests/run.sh selfcheck` | 以上全部，不需要 `--sut` |
| `ceshi test local`（默认 g-lite main） | **删除 fallback**。必须 `--sut` | 禁止静默测错树 |
| `ceshi test local 1` | `tests/run.sh local --suite 1 --sut PATH` | mutex/finalize + v1 夹具 + `new check --tier commit` |
| `ceshi test local 13` | `tests/run.sh local --suite 13 --sut PATH` | mutex + `completion.test.sh` + commit |
| `ceshi test local 14` | `tests/run.sh local --suite 14 --sut PATH` | mutex + guard + `guard-issue14.test.sh` + `check-guard-recovery.sh` + commit |
| `ceshi test local 33` / `41` | `tests/run.sh local --suite 33 --sut PATH` | mutex + `contract.test.sh` + commit |
| `ceshi test local 42` | `tests/run.sh local --suite 42 --sut PATH` | mutex + `metrics.test.sh` + commit |
| `ceshi test local 28`–`31` | `tests/run.sh local --suite 28 --sut PATH` | mutex + commit |
| 单接口 | `tests/run.sh local --scenario completion --sut PATH` | 仅该脚本；缺文件即失败 |
| `ceshi test facts --yes` | `tests/run.sh facts --yes` | squash / lease / Refs-Fixes |
| `ceshi test zmerge [n] --yes` | `tests/run.sh zmerge-delete --sut PATH --yes` | 只验 `zmerge_delete_remote_branch` |
| `tests/e2e/run.sh facts` | 同上 | 兼容转调 |

命名 suite 也可写 `completion`、`guard-recovery`、`contract`、`metrics`、`v1`、`mutex`、`commit`。

直接跑叶子脚本同样要 opt-in，例如：

```bash
HARNESS_E2E_YES=1 bash tests/e2e/facts-squash.sh
bash tests/e2e/zmerge-delete.sh --sut PATH --yes
```
