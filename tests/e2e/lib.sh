# 兼容旧 source 路径，转给 tests/lib/bootstrap.sh。
_e2e_harness_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/bootstrap.sh
. "$_e2e_harness_root/tests/lib/bootstrap.sh"
