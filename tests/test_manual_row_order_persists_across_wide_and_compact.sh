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

controller move-up three >/dev/null
order_before="$(controller list-agents | awk -F $'\t' '{print $1}' | paste -sd ' ' -)"
assert_eq "three one two" "$order_before" "manual agent row order should update immediately"

controller wide >/dev/null
controller compact >/dev/null
order_after="$(controller list-agents | awk -F $'\t' '{print $1}' | paste -sd ' ' -)"
assert_eq "three one two" "$order_after" "manual agent row order should persist across wide and compact mode switches"

echo "ok - manual compact row order persists across wide and compact"
