#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
pane_two="$(tmux_test split-window -d -h -t "$pane_one" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"
pane_three="$(tmux_test split-window -d -h -t "$pane_two" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"
pane_four="$(tmux_test split-window -d -v -t "$pane_three" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"

register_pane "$pane_one" one
register_pane "$pane_two" two
register_pane "$pane_three" three
register_pane "$pane_four" four

layout_before="$(tmux_test display-message -p -t "$TEST_SESSION_NAME":main '#{window_layout}')"
geometry_before="$(tmux_test list-panes -t "$TEST_SESSION_NAME":main -F '#{pane_width}x#{pane_height}	#{pane_left},#{pane_top}' | sort)"
controller compact >/dev/null

assert_eq "$layout_before" "$(session_option @agents_sidebar_wide_layout)" "compact should save the current wide layout string"
assert_eq "0" "$(session_option @agents_sidebar_wide_layout_dirty)" "saved wide layout should start clean"

controller wide >/dev/null
geometry_after="$(tmux_test list-panes -t "$(pane_window_id "$pane_one")" -F '#{pane_width}x#{pane_height}	#{pane_left},#{pane_top}' | sort)"

assert_eq "$geometry_before" "$geometry_after" "wide should restore the saved custom pane geometry instead of forcing even-horizontal"

echo "ok - wide layout persists across compact and wide restore"
