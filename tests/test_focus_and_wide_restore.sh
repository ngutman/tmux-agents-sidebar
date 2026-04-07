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

store_session_before="$(session_option @agents_sidebar_store_session)"
store_window_before="$(session_option @agents_sidebar_store_window)"
compact_window="$(session_option @agents_sidebar_compact_window)"

controller focus-keep-sidebar two >/dev/null
status_after_focus="$(status_output)"
sidebar_pane="$(session_option @agents_sidebar_pane)"
assert_contains "active_name: two" "$status_after_focus" "focus should switch the active label"
assert_eq "$pane_two" "$(session_option @agents_sidebar_focus_pane)" "focus pane option should track the newly focused pane"
assert_eq "$compact_window" "$(pane_window_id "$pane_two")" "focused pane should move into the visible compact window"
assert_eq "$store_window_before" "$(pane_window_id "$pane_one")" "previously active pane should move into the detached store window"
assert_eq "$sidebar_pane" "$(active_pane_in_window "$compact_window")" "focus-keep-sidebar should leave keyboard focus in the sidebar"

controller wide >/dev/null

assert_empty "$(session_option @agents_sidebar_store_session)" "wide mode should clear the detached store session option"
assert_empty "$(session_option @agents_sidebar_store_window)" "wide mode should clear the detached store window option"
assert_empty "$(session_option @agents_sidebar_pane)" "wide mode should remove the sidebar pane"
assert_empty "$(session_option @agents_sidebar_focus_pane)" "wide mode should clear the focused pane option"

if tmux_test has-session -t "$store_session_before" 2>/dev/null; then
  fail "wide mode should destroy the detached store session"
fi

assert_eq "1" "$(session_window_count)" "wide mode should leave a single main-session window"
window_one="$(pane_window_id "$pane_one")"
window_two="$(pane_window_id "$pane_two")"
assert_eq "$window_one" "$window_two" "wide mode should bring both panes back into the same window"

snapshot_after_wide="$(snapshot_output)"
assert_contains $'entry\tone\t'"$pane_one" "$snapshot_after_wide" "wide snapshot should include pane one"
assert_contains $'entry\ttwo\t'"$pane_two" "$snapshot_after_wide" "wide snapshot should include pane two"

echo "ok - focus swaps through the store and wide restores panes"
