# 测试入口

Harness 测试不再经过 `ceshi start`、Issue 队列或 worktree 目录后缀。主入口：

```bash
tests/run.sh selfcheck
tests/run.sh local --suite 14 --sut /path/to/g-lite-revision
tests/run.sh facts --yes
tests/run.sh zmerge-delete --sut /path/to/g-lite-revision --yes
```

从任意 cwd 用脚本绝对路径调用即可。`--sut` 是外部被测代码的固定版本；默认 `--isolate` 复制到可丢弃目录，不改用户现有 checkout。

真实 GitHub 写入必须 `--yes`（或 `HARNESS_E2E_YES=1`），只打 `qiaoen12/g-lite-harness` 的 `e2e/*`，squash 只进 `e2e/base`。叶子脚本同样检查目标和 opt-in。

`zmerge-delete` 只验证 `zmerge_delete_remote_branch`，不是完整 `zmerge_run`。缺少 SUT 文件时报失败/未验证，不转去修改 g-lite。

旧命令对照见 [MIGRATION.md](MIGRATION.md)。运行证据写在仓内 `.tmp/evidence/`（已忽略）。
