# 测试入口公共加载。不加载生命周期模块（cmd / worktree / common / github）。

if [ "${HARNESS_BOOTSTRAP_DONE:-}" = 1 ]; then
  return 0 2>/dev/null || exit 0
fi
HARNESS_BOOTSTRAP_DONE=1

if [ -z "${HARNESS_ROOT:-}" ]; then
  HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export HARNESS_ROOT

# shellcheck source=root.sh
. "$HARNESS_ROOT/tests/lib/root.sh"
harness_verify_root "$HARNESS_ROOT"

# shellcheck source=identity.sh
. "$HARNESS_ROOT/tests/lib/identity.sh"
# shellcheck source=result.sh
. "$HARNESS_ROOT/tests/lib/result.sh"
# shellcheck source=../../lib/parse.sh
. "$HARNESS_ROOT/lib/parse.sh"
# shellcheck source=sandbox.sh
. "$HARNESS_ROOT/tests/lib/sandbox.sh"
# shellcheck source=sut.sh
. "$HARNESS_ROOT/tests/lib/sut.sh"
# shellcheck source=local.sh
. "$HARNESS_ROOT/tests/lib/local.sh"
# shellcheck source=e2e.sh
. "$HARNESS_ROOT/tests/lib/e2e.sh"

if [ "${CESHI_YES:-}" = 1 ]; then
  HARNESS_E2E_YES=1
fi
for _harness_arg in "$@"; do
  if [ "$_harness_arg" = --yes ]; then
    HARNESS_E2E_YES=1
    CESHI_YES=1
  fi
done
unset _harness_arg

harness_require_pins
