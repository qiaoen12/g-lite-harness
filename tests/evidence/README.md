# 运行证据

`tests/run.sh facts` / `zmerge-delete` 会把 Harness HEAD、SUT 路径与 HEAD、残留对象写到仓库 `.tmp/evidence/`（git 已忽略）。

本地自检不强制留文件。真实 GitHub 跑完后核对：

- 测试对象是否仍为本次 `e2e/*`
- squash 是否只进入 `e2e/base`
- Refs/Fixes Draft 是否已关闭且未合入 `main`
- cleanup 失败时的 `LEFTOVER` / `RECOVERY` 行
