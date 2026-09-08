#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
kind="${1:-facts}"
case "$kind" in
  facts)
    bash "$HERE/facts-squash.sh"
    bash "$HERE/facts-lease.sh"
    bash "$HERE/refs-fixes.sh"
    ;;
  zmerge)
    bash "$HERE/zmerge-delete.sh"
    ;;
  *)
    echo "用法：run.sh facts|zmerge" >&2
    exit 2
    ;;
esac
