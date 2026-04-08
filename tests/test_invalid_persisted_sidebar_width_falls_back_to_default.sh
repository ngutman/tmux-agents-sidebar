#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_two="$(new_test_pane "$PROJECT_ROOT")"
register_pane "$TEST_PRIMARY_PANE" one
register_pane "$pane_two" two

tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_width 197
controller compact >/dev/null

snapshot="$(snapshot_output)"
sidebar_pane="$(session_option @agents_sidebar_pane)"
sidebar_width="$(tmux_test display-message -p -t "$sidebar_pane" '#{pane_width}')"

assert_contains $'size\t45\t' "$snapshot" "invalid persisted sidebar width should fall back to the default width"
assert_eq "45" "$sidebar_width" "sidebar pane should be created with the default width when persisted width is invalid"
assert_eq "45" "$(session_option @agents_sidebar_width)" "session sidebar width option should be healed back to the default width"

echo "ok - invalid persisted sidebar width falls back to default"
