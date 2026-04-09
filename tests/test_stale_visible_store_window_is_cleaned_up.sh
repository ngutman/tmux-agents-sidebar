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

orphan_window="$(tmux_test new-window -d -P -F '#{window_id}' -t "$TEST_SESSION_ID" -n '__agents_sidebar_store' -c "$PROJECT_ROOT")"
orphan_pane="$(tmux_test list-panes -t "$orphan_window" -F '#{pane_id}' | awk 'NR == 1 { print; exit }')"
tmux_test select-pane -t "$orphan_pane" -T '__agents_sidebar_store_placeholder'

controller compact >/dev/null

window_names="$(list_session_window_names)"
assert_not_contains "__agents_sidebar_store" "$window_names" "compact should remove stale visible store windows from the active session"

store_session="$(session_option @agents_sidebar_store_session)"
store_window="$(session_option @agents_sidebar_store_window)"
store_owner="$(tmux_test list-windows -a -F '#{window_id}	#{session_id}' | awk -F $'\t' -v target="$store_window" '$1 == target { print $2; exit }')"
assert_nonempty "$store_session" "compact should record a detached store session"
assert_nonempty "$store_window" "compact should record a detached store window"
assert_eq "$store_session" "$store_owner" "store window should belong to the detached store session"
[[ "$store_owner" != "$TEST_SESSION_ID" ]] || fail "store window should not stay in the active session"

echo "ok - compact cleans up stale visible store windows"
