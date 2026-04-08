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

controller compact >/dev/null
compact_window="$(session_option @agents_sidebar_compact_window)"
active_pane="$(session_option @agents_sidebar_focus_pane)"

set +e
AGENTS_SIDEBAR_SESSION="$TEST_SESSION_ID" \
AGENTS_SIDEBAR_PANE="$active_pane" \
AGENTS_SIDEBAR_WINDOW="$compact_window" \
bash "$PROJECT_ROOT/scripts/agents-sidebar" kill-current >/tmp/agents-sidebar-kill-current.out 2>/tmp/agents-sidebar-kill-current.err
status=$?
set -e

if [[ "$status" -ne 0 ]]; then
  cat /tmp/agents-sidebar-kill-current.err >&2 || true
fi
rm -f /tmp/agents-sidebar-kill-current.out /tmp/agents-sidebar-kill-current.err

assert_eq "0" "$status" "kill-current should succeed when invoked like the tmux key binding"
assert_eq "1" "$(session_option @agents_sidebar_wide_layout_dirty)" "kill-current should still dirty the saved wide layout"

echo "ok - kill-current binding path does not trip SIGPIPE"
