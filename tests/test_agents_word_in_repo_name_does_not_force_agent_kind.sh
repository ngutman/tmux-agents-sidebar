#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "$0")" && pwd)/helpers/test_lib.sh"
trap cleanup_test_server EXIT
setup_test_server

repo_path="$TEST_TMPDIR/tmux-agents-sidebar"
create_git_repo "$repo_path" main

shell_pane="$(new_test_pane "$repo_path")"
set_pane_title "$shell_pane" "test-host.local"
window_id="$(pane_window_id "$shell_pane")"

after_snapshot="$(snapshot_output)"
status="$(status_output)"
shell_line="$(printf '%s\n' "$after_snapshot" | awk -F $'\t' -v pane="$shell_pane" '$1 == "entry" && $3 == pane { print; exit }')"

assert_contains $'\t'"$window_id"$'\tmain\tpane\tshell' "$shell_line" "shell pane in a repo with 'agents' in its name should remain a pane"
assert_contains "panes:" "$status" "status should print a panes section"
assert_contains "tmux-agents-sidebar@main" "$status" "status should include the shell pane label"

echo "ok - repo names containing agents do not force shell panes into the agents section"
