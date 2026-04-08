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
client_one_tty="$LAST_TEST_CLIENT_TTY"
start_test_client 120 40
AGENTS_SIDEBAR_CLIENT_TTY="$client_one_tty" controller maybe-auto-compact >/dev/null
sleep 1

[[ "$(session_option @agents_sidebar_mode)" != "compact" ]] || fail "auto-compact should not run when multiple clients are attached"
assert_empty "$(session_option @agents_sidebar_pending_auto_compact_token)" "multi-client sessions should not keep a pending auto-compact token"

echo "ok - auto-compact is suppressed when multiple clients are attached"
