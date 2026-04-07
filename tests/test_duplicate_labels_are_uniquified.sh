#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_one="$TEST_PRIMARY_PANE"
pane_two="$(new_test_pane)"

register_pane "$pane_one" dup
register_pane "$pane_two" dup

snapshot="$(snapshot_output)"
status="$(status_output)"

assert_contains $'entry	dup	'"$pane_one" "$snapshot" "first pane should keep the requested label"
assert_contains $'entry	dup-2	'"$pane_two" "$snapshot" "second duplicate label should be uniquified"
assert_contains $'active_name: ' "$status" "status output should still be readable after duplicate registration"

controller compact >/dev/null
controller focus dup-2 >/dev/null

assert_eq "$pane_two" "$(session_option @agents_sidebar_focus_pane)" "focus should target the uniquified label"
assert_contains "active_name: dup-2" "$(status_output)" "compact state should track the uniquified active label"

echo "ok - duplicate labels are uniquified deterministically"
