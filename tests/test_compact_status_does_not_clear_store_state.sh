#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
pane_two="$(new_test_pane)"

register_pane "$pane_one" one
register_pane "$pane_two" two
controller compact >/dev/null

foreign_session="$(tmux_test new-session -d -P -F '#{session_id}' -s foreign-store-status -n '__agents_sidebar_store' -c "$PROJECT_ROOT")"
foreign_window="$(tmux_test list-windows -t "$foreign_session" -F '#{window_id}' | awk 'NR == 1 { print; exit }')"
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_store_session "$foreign_session"
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_store_window "$foreign_window"

controller status >/dev/null
assert_eq "$foreign_session" "$(session_option @agents_sidebar_store_session)" "status should not clear compact store session state"
assert_eq "$foreign_window" "$(session_option @agents_sidebar_store_window)" "status should not clear compact store window state"

set +e
controller new >/tmp/agents-sidebar-new.out 2>/tmp/agents-sidebar-new.err
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  cat /tmp/agents-sidebar-new.err >&2 || true
fi
rm -f /tmp/agents-sidebar-new.out /tmp/agents-sidebar-new.err
assert_eq "0" "$status" "new should not fail after status in compact mode"

echo "ok - compact status does not clear store state"
