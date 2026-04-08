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
resize_test_client "$LAST_TEST_CLIENT_CMD_FILE" 160 40
wait_until "tmux_test list-clients -t '$TEST_SESSION_ID' -F '#{client_tty} #{client_width}' | grep -Fxq '$LAST_TEST_CLIENT_TTY 160'" 5
sleep 0.6
AGENTS_SIDEBAR_SESSION="$TEST_SESSION_ID" AGENTS_SIDEBAR_CLIENT_TTY="$LAST_TEST_CLIENT_TTY" controller run-auto-compact "$token" >/dev/null
assert_empty "$(session_option @agents_sidebar_pending_auto_compact_token)" "expanded clients should clear the pending auto-compact token"
[[ "$(session_option @agents_sidebar_mode)" != "compact" ]] || fail "auto-compact should cancel if the client expands before the debounce run"

echo "ok - auto-compact cancels if the client expands before the debounce fires"
