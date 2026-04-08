#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
register_pane "$pane_one" one

missing_window='@999999'
set +e
AGENTS_SIDEBAR_SESSION="$TEST_SESSION_ID" \
AGENTS_SIDEBAR_PANE="$pane_one" \
AGENTS_SIDEBAR_WINDOW="$missing_window" \
bash "$PROJECT_ROOT/scripts/agents-sidebar" save-wide-layout >/tmp/agents-sidebar-save-wide.out 2>/tmp/agents-sidebar-save-wide.err
status=$?
set -e

if [[ "$status" -ne 0 ]]; then
  cat /tmp/agents-sidebar-save-wide.err >&2 || true
fi
rm -f /tmp/agents-sidebar-save-wide.out /tmp/agents-sidebar-save-wide.err

assert_eq "0" "$status" "save-wide-layout should ignore stale hook windows"

echo "ok - save-wide-layout ignores missing hook windows"
