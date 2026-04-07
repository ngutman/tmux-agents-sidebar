#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers/test_lib.sh"

setup_test_server
trap cleanup_test_server EXIT

repo_main="$TEST_TMPDIR/repo-main"
repo_copy="$TEST_TMPDIR/repo-copy"
create_git_repo "$repo_main" main
create_git_repo "$repo_copy" copy-2

pane_main="$(new_test_pane "$repo_main")"
pane_copy="$(new_test_pane "$repo_copy")"

register_pane "$pane_main" mainbox
register_pane "$pane_copy" copybox
controller compact >/dev/null

snapshot="$(snapshot_output)"
line_main="$(printf '%s\n' "$snapshot" | grep -F $'entry\tmainbox\t' | head -n1)"
line_copy="$(printf '%s\n' "$snapshot" | grep -F $'entry\tcopybox\t' | head -n1)"

assert_contains $'\trepo-main\tmain\t' "$line_main" "mainbox should report the main branch from its cwd"
assert_contains $'\trepo-copy\tcopy-2\t' "$line_copy" "copybox should report its own branch instead of inheriting another pane's branch"
assert_contains $'size\t45\t' "$snapshot" "default sidebar width should be 45 columns"

echo "ok - sidebar detects per-pane git branches and defaults to width 45"
