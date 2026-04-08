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
focus_pane="$(session_option @agents_sidebar_focus_pane)"
extra_sidebar="$(tmux_test split-window -d -h -t "$focus_pane" -l 5 -P -F '#{pane_id}')"
tmux_test select-pane -t "$extra_sidebar" -T '__agents_sidebar_nav'

before_count="$(tmux_test list-panes -t "$compact_window" -F '#{pane_title}' | grep -c '^__agents_sidebar_nav$' | tr -d ' ')"
assert_eq "2" "$before_count" "test setup should create a duplicate sidebar pane"

controller compact >/dev/null
after_count="$(tmux_test list-panes -t "$compact_window" -F '#{pane_title}' | grep -c '^__agents_sidebar_nav$' | tr -d ' ')"
assert_eq "1" "$after_count" "compact refresh should collapse duplicate sidebar panes back to one"

controller wide >/dev/null
remaining_count="$(tmux_test list-panes -a -F '#{pane_title}' | grep -c '^__agents_sidebar_nav$' || true)"
remaining_count="${remaining_count//$'\n'/}"
remaining_count="${remaining_count// /}"
assert_eq "0" "$remaining_count" "wide mode should remove orphan sidebar panes"

echo "ok - duplicate and orphan sidebar panes are cleaned up"
