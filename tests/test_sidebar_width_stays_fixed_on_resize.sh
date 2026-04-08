#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_two="$(new_test_pane "$PROJECT_ROOT")"
register_pane "$TEST_PRIMARY_PANE" one
register_pane "$pane_two" two
controller compact >/dev/null

compact_window="$(session_option @agents_sidebar_compact_window)"
sidebar_pane="$(session_option @agents_sidebar_pane)"
assert_eq "45" "$(tmux_test display-message -p -t "$sidebar_pane" '#{pane_width}')" "sidebar should start at the default width"

tmux_test resize-window -x 120 -y 30 -t "$compact_window"
assert_eq "65" "$(tmux_test display-message -p -t "$sidebar_pane" '#{pane_width}')" "tmux should expand the sidebar width before the controller reapplies it"

controller maintain-sidebar-width >/dev/null
assert_eq "45" "$(tmux_test display-message -p -t "$sidebar_pane" '#{pane_width}')" "maintain-sidebar-width should restore the configured width after window resize"

echo "ok - compact sidebar width stays fixed when resized"
