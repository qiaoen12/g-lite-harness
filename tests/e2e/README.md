# 仅保留必须打真实 GitHub 的外部 E2E。不是测试框架。

直接运行叶子脚本（需要 `--yes`）：

```bash
bash tests/e2e/facts-squash.sh --yes
bash tests/e2e/facts-lease.sh --yes
bash tests/e2e/refs-fixes.sh --yes
bash tests/e2e/zmerge-delete.sh --yes --sut /path/to/g-lite
```

只写 `qiaoen12/g-lite-harness` 的 `e2e/*`，squash 只进 `e2e/base`。不合入 Harness main，不写 g-lite main。
`zmerge-delete.sh` 只验 `zmerge_delete_remote_branch`，路径必须显式给出。

g-lite 日常开发用原生 git/gh，不经过本仓。
