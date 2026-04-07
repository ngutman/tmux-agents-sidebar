#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_agent="$TEST_PRIMARY_PANE"
pane_pi="$(new_test_pane)"
pane_shell="$(new_test_pane)"

register_pane "$pane_agent" orch
set_pane_title "$pane_pi" "π - sidebar-bot"
set_pane_status "$pane_pi" error
mark_pane "$pane_shell" shellbox

snapshot="$(snapshot_output)"
status="$(status_output)"

assert_contains $'entry\torch\t'"$pane_agent"$'\t@0\tmain\tagent\tunknown\tidle' "$snapshot" "registered pane should be classified as an idle agent"
assert_contains $'entry\tsidebar-bot\t'"$pane_pi"$'\t@0\tmain\tagent\tpi\terror' "$snapshot" "pi heuristic should classify the pane as a pi agent with error status"
assert_contains $'entry\tshellbox\t'"$pane_shell"$'\t@0\tmain\tpane' "$snapshot" "explicit regular pane should stay classified as a pane"

assert_contains "agents:" "$status" "status should print an agents section"
assert_contains "panes:" "$status" "status should print a panes section"
assert_contains "orch" "$status" "status should include the registered agent"
assert_contains "sidebar-bot" "$status" "status should include the detected pi agent"
assert_contains "shellbox" "$status" "status should include the regular pane"

echo "ok - snapshot separates agents and panes with metadata and heuristics"
