#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_two="$(new_test_pane "$PROJECT_ROOT")"
register_pane "$TEST_PRIMARY_PANE" one
register_pane "$pane_two" two

tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_auto_compact_on_narrow 1
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_auto_compact_width 130

start_test_client 120 40
AGENTS_SIDEBAR_CLIENT_TTY="$LAST_TEST_CLIENT_TTY" controller maybe-auto-compact >/dev/null

token="$(session_option @agents_sidebar_pending_auto_compact_token)"
assert_nonempty "$token" "auto-compact should queue a pending token before the debounce delay"
AGENTS_SIDEBAR_SESSION="$TEST_SESSION_ID" AGENTS_SIDEBAR_CLIENT_TTY="$LAST_TEST_CLIENT_TTY" controller run-auto-compact "$token" >/dev/null

assert_eq "compact" "$(session_option @agents_sidebar_mode)" "queued auto-compact should compact once the debounce window has passed"
assert_eq "auto-narrow" "$(session_option @agents_sidebar_compact_reason)" "auto-compact should mark the compact reason"
assert_nonempty "$(session_option @agents_sidebar_store_session)" "auto-compact should move inactive panes into a detached store"

echo "ok - auto-compact debounces and compacts for a narrow single client"
