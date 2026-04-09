#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
pane_two="$(new_test_pane)"
pane_three="$(tmux_test split-window -d -h -t "$pane_two" -c "$PROJECT_ROOT" -P -F '#{pane_id}')"

register_pane "$pane_one" one
register_pane "$pane_two" two
register_pane "$pane_three" three
controller compact >/dev/null

initial_order="$(controller list-agents | awk -F $'\t' '{print $1}' | paste -sd ' ' -)"
assert_eq "one three two" "$initial_order" "agents should start in derived order before any manual movement"

controller move-up two >/dev/null
agent_order="$(controller list-agents | awk -F $'\t' '{print $1}' | paste -sd ' ' -)"
assert_eq "one two three" "$agent_order" "move-up should reorder agents within the agents section"

controller move-down two >/dev/null
agent_order="$(controller list-agents | awk -F $'\t' '{print $1}' | paste -sd ' ' -)"
assert_eq "one three two" "$agent_order" "move-down should move the agent back down within the agents section"

echo "ok - compact mode can move agent rows within their section"
