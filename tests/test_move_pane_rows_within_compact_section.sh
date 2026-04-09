#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_agent="$TEST_PRIMARY_PANE"
pane_one="$(new_test_pane)"
pane_two="$(tmux_test split-window -d -h -t "$pane_one" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"
pane_three="$(tmux_test split-window -d -h -t "$pane_two" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"

mark_agent "$pane_agent" pi orch
mark_pane "$pane_one" alpha
mark_pane "$pane_two" beta
mark_pane "$pane_three" gamma
controller compact >/dev/null

agent_entry="$(controller list-entries | awk -F $'\t' 'NR == 1 {print $1":"$5}')"

controller move-up beta >/dev/null
entry_order="$(controller list-entries | awk -F $'\t' '{print $1":"$5}' | paste -sd ' ' -)"
assert_eq "$agent_entry beta:pane alpha:pane gamma:pane" "$entry_order" "moving a pane should only reorder rows within the panes section"

controller move-down beta >/dev/null
entry_order="$(controller list-entries | awk -F $'\t' '{print $1":"$5}' | paste -sd ' ' -)"
assert_eq "$agent_entry alpha:pane beta:pane gamma:pane" "$entry_order" "moving the pane back down should restore pane order without affecting agents"

echo "ok - compact mode can move pane rows within the panes section"
