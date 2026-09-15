#!/usr/bin/env bash
# 可选串跑。叶子脚本也可单独执行。
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
kind="${1:-facts}"
shift || true
case "$kind" in
  facts)
    bash "$HERE/facts-squash.sh" "$@"
    bash "$HERE/facts-lease.sh" "$@"
    bash "$HERE/refs-fixes.sh" "$@"
    ;;
  zmerge)
    bash "$HERE/zmerge-delete.sh" "$@"
    ;;
  *)
    echo "用法：tests/e2e/run.sh facts --yes | zmerge --yes --sut PATH" >&2
    exit 2
    ;;
esac
