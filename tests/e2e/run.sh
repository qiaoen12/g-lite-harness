#!/usr/bin/env bash
# 兼容旧 tests/e2e/run.sh。转给 tests/run.sh。
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kind="${1:-facts}"
shift || true
case "$kind" in
  facts) exec bash "$HERE/../run.sh" facts "$@" ;;
  zmerge) exec bash "$HERE/../run.sh" zmerge-delete "$@" ;;
  *)
    echo "用法：run.sh facts|zmerge  （新入口 tests/run.sh）" >&2
    exit 2
    ;;
esac
