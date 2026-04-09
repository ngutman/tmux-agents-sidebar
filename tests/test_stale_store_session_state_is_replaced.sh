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

foreign_session="$(tmux_test new-session -d -P -F '#{session_id}' -s foreign-store -n '__agents_sidebar_store' -c "$PROJECT_ROOT")"
foreign_window="$(tmux_test list-windows -t "$foreign_session" -F '#{window_id}' | awk 'NR == 1 { print; exit }')"
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_store_session "$foreign_session"
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_store_window "$foreign_window"

controller compact >/dev/null

store_session="$(session_option @agents_sidebar_store_session)"
store_window="$(session_option @agents_sidebar_store_window)"
store_session_name="$(tmux_test list-sessions -F '#{session_id}	#{session_name}' | awk -F $'\t' -v target="$store_session" '$1 == target { print $2; exit }')"
expected_store_name="__agents_sidebar_store_${TEST_SESSION_ID//[^[:alnum:]]/_}"

assert_nonempty "$store_session" "compact should record a store session"
assert_nonempty "$store_window" "compact should record a store window"
[[ "$store_session" != "$foreign_session" ]] || fail "compact should replace stale foreign store session state"
assert_eq "$expected_store_name" "$store_session_name" "compact should create the canonical detached store session"
tmux_test has-session -t "$foreign_session" || fail "cleanup should not kill unrelated foreign sessions"

echo "ok - compact replaces stale store session state"
