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

assert_eq "1" "$(session_window_count)" "compact mode should keep a single visible window in the main session"
window_names="$(list_session_window_names)"
assert_contains "main" "$window_names" "main window should remain visible"
assert_not_contains "__agents_sidebar_compact" "$window_names" "compact helper window should not exist"
assert_not_contains "__agents_sidebar_pool" "$window_names" "pool helper window should not exist"

store_session="$(session_option @agents_sidebar_store_session)"
store_window="$(session_option @agents_sidebar_store_window)"
assert_nonempty "$store_session" "compact mode should record the detached store session"
assert_nonempty "$store_window" "compact mode should record the detached store window"
tmux_test has-session -t "$store_session" || fail "detached store session should exist"

snapshot="$(snapshot_output)"
assert_contains $'entry\tone\t'"$pane_one" "$snapshot" "snapshot should include the active pane"
assert_contains $'entry\ttwo\t'"$pane_two" "$snapshot" "snapshot should include the inactive pane"
assert_contains $'entry\ttwo\t'"$pane_two"$'\t'"$store_window"$'\t__agents_sidebar_store\tagent' "$snapshot" "inactive pane should live in the detached store window as an agent entry"

focus_pane="$(session_option @agents_sidebar_focus_pane)"
focus_title="$(tmux_test display-message -p -t "$focus_pane" '#{pane_title}')"
assert_not_contains "__agents_sidebar_store_placeholder" "$focus_title" "active pane title should not be replaced by the store placeholder"

echo "ok - compact mode uses a detached store session"
