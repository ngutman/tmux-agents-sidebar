#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

pane_pi="$TEST_PRIMARY_PANE"
mark_pane "$pane_pi" clawhub
set_pane_title "$pane_pi" "π - clawhub"
tmux_test set-option -p -q -t "$pane_pi" @pi_session_state running

snapshot="$(snapshot_output)"
status="$(status_output)"
line="$(printf '%s\n' "$snapshot" | awk -F $'\t' -v pane="$pane_pi" '$1 == "entry" && $3 == pane { print; exit }')"

assert_contains $'\tagent\tpi\trunning' "$line" "stale pane metadata should upgrade to an agent when live pi evidence is present"
assert_contains "clawhub" "$status" "status should include the upgraded pi agent"
assert_eq "agent" "$(session_option @agents_sidebar_kind_${pane_pi#%})" "pane kind metadata should be healed to agent"

echo "ok - stale pane kind upgrades to agent for live pi panes"
