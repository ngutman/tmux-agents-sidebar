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
controller compact >/dev/null
assert_eq "0" "$(session_option @agents_sidebar_wide_layout_dirty)" "saved wide layout should start clean"

store_window="$(session_option @agents_sidebar_store_window)"
dead_pane="$(tmux_test list-panes -t "$store_window" -F '#{pane_id} #{pane_title}' | awk '$2 != "__agents_sidebar_store_placeholder" { print $1; exit }')"
assert_nonempty "$dead_pane" "compact mode should have an inactive stored pane to kill"

tmux_test kill-pane -t "$dead_pane"
controller cleanup-dead >/dev/null
assert_eq "1" "$(session_option @agents_sidebar_wide_layout_dirty)" "unexpected compact pane death should dirty the saved wide layout"

controller wide >/dev/null
layout_after="$(tmux_test display-message -p -t "$(session_option @agents_sidebar_wide_layout_window)" '#{window_layout}')"
[[ "$layout_after" != "$layout_before" ]] || fail "wide restore should fall back after an unexpected compact pane death"

echo "ok - unexpected compact pane death marks the saved wide layout dirty"
