#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "$0")" && pwd)/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_two="$(new_test_pane)"
mark_agent "$TEST_PRIMARY_PANE" pi one
mark_agent "$pane_two" pi two

tmux_test rename-window -t "$TEST_SESSION_NAME":main '__agents_sidebar_store'
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_mode wide
tmux_test set-option -qu -t "$TEST_SESSION_ID" @agents_sidebar_store_session
tmux_test set-option -qu -t "$TEST_SESSION_ID" @agents_sidebar_store_window

after_before="$(list_session_window_names)"
assert_contains "__agents_sidebar_store" "$after_before" "test setup should leave a visible store window as the only session window"

controller compact >/dev/null

assert_eq "compact" "$(session_option @agents_sidebar_mode)" "compact should recover when the only visible window is a stale store window"
assert_nonempty "$(session_option @agents_sidebar_compact_window)" "compact should create or reuse a visible compact window"
assert_nonempty "$(session_option @agents_sidebar_store_session)" "compact should recreate detached store session state during recovery"
assert_nonempty "$(session_option @agents_sidebar_store_window)" "compact should recreate detached store window state during recovery"
assert_not_contains "__agents_sidebar_store" "$(list_session_window_names)" "compact recovery should not leave the only visible session window named as the internal store"
snapshot="$(snapshot_output)"
entry_count="$(printf '%s\n' "$snapshot" | grep -c '^entry' | tr -d ' ')"
assert_eq "2" "$entry_count" "snapshot should still include both recovered entries"
assert_contains $'	@0	agents-sidebar	' "$snapshot" "snapshot should include a visible recovered compact window entry"
assert_contains $'	__agents_sidebar_store	' "$snapshot" "snapshot should include an inactive entry in the detached store window"

echo "ok - compact recovers if the only visible session window is a stale store window"
