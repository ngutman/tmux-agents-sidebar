#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
pane_two="$(new_test_pane "$PROJECT_ROOT")"
register_pane "$pane_one" one
register_pane "$pane_two" two

controller compact >/dev/null
compact_window="$(session_option @agents_sidebar_compact_window)"
store_window="$(session_option @agents_sidebar_store_window)"
sidebar_pane="$(session_option @agents_sidebar_pane)"
store_pane="$(tmux_test list-panes -t "$store_window" -F '#{pane_id} #{pane_title}' | awk '$2 != "__agents_sidebar_store_placeholder" { print $1; exit }')"
visible_pane="$(tmux_test list-panes -t "$compact_window" -F '#{pane_id} #{pane_title}' | awk -v sidebar="$sidebar_pane" '$1 != sidebar { print $1; exit }')"
visible_name="$(controller list-entries | awk -F $'\t' -v pane="$visible_pane" '$2 == pane { print $1; exit }')"

assert_nonempty "$store_pane" "compact mode should have an inactive stored pane"
assert_nonempty "$visible_pane" "compact mode should have a visible focus pane"

tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_focus_pane "$store_pane"
tmux_test set-option -q -t "$TEST_SESSION_ID" @agents_sidebar_active_name bogus
controller refresh >/dev/null

assert_eq "$visible_pane" "$(session_option @agents_sidebar_focus_pane)" "refresh should repair focus_pane to the visible compact pane"
assert_eq "$visible_name" "$(session_option @agents_sidebar_active_name)" "refresh should repair active_name to match the visible compact pane"

echo "ok - refresh repairs compact focus when state points into the store"
