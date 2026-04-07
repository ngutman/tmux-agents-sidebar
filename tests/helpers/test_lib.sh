#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$CURRENT_DIR/../.." && pwd)"
CONTROLLER="$PROJECT_ROOT/scripts/agents-sidebar"
REAL_TMUX="$(command -v tmux)"

TEST_SOCKET=""
TEST_SESSION_NAME="agents-sidebar-test"
TEST_SESSION_ID=""
TEST_PRIMARY_PANE=""
TEST_PATH_DIR=""
TEST_TMPDIR=""
TEST_HOME=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="${3:-expected '$expected' but got '$actual'}"
  [[ "$expected" == "$actual" ]] || fail "$message"
}

assert_nonempty() {
  local value="$1"
  local message="${2:-expected non-empty value}"
  [[ -n "$value" ]] || fail "$message"
}

assert_empty() {
  local value="$1"
  local message="${2:-expected empty value}"
  [[ -z "$value" ]] || fail "$message"
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local message="${3:-expected to find '$needle'}"
  [[ "$haystack" == *"$needle"* ]] || fail "$message"
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  local message="${3:-did not expect to find '$needle'}"
  [[ "$haystack" != *"$needle"* ]] || fail "$message"
}

tmux_test() {
  "$REAL_TMUX" -L "$TEST_SOCKET" "$@"
}

setup_test_server() {
  TEST_SOCKET="agents-sidebar-test-${RANDOM}-$$"
  TEST_TMPDIR="$(mktemp -d)"
  TEST_HOME="$TEST_TMPDIR/home"
  TEST_PATH_DIR="$TEST_TMPDIR/bin"
  mkdir -p "$TEST_HOME/.tmux" "$TEST_PATH_DIR"

  cat > "$TEST_PATH_DIR/tmux" <<EOF
#!/usr/bin/env bash
exec "$REAL_TMUX" -L "$TEST_SOCKET" "\$@"
EOF
  chmod +x "$TEST_PATH_DIR/tmux"

  PATH="$TEST_PATH_DIR:$PATH" HOME="$TEST_HOME" \
    "$REAL_TMUX" -L "$TEST_SOCKET" -f /dev/null new-session -d -s "$TEST_SESSION_NAME" -n main -c "$PROJECT_ROOT"

  TEST_PRIMARY_PANE="$(tmux_test list-panes -t "$TEST_SESSION_NAME":main -F '#{pane_id}' | head -n1)"
  TEST_SESSION_ID="$(tmux_test display-message -p -t "$TEST_PRIMARY_PANE" '#{session_id}')"

  export PATH="$TEST_PATH_DIR:$PATH"
  export HOME="$TEST_HOME"
  export AGENTS_SIDEBAR_SESSION="$TEST_SESSION_ID"
  export AGENTS_SIDEBAR_PANE="$TEST_PRIMARY_PANE"
}

cleanup_test_server() {
  if [[ -n "$TEST_SOCKET" ]]; then
    "$REAL_TMUX" -L "$TEST_SOCKET" kill-server >/dev/null 2>&1 || true
  fi
  if [[ -n "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR" >/dev/null 2>&1 || true
  fi
}

controller() {
  "$CONTROLLER" "$@"
}

new_test_pane() {
  local path="${1:-$PROJECT_ROOT}"
  tmux_test split-window -d -h -t "$TEST_SESSION_NAME":main -c "$path" -P -F '#{pane_id}'
}

create_git_repo() {
  local path="$1"
  local branch="${2:-main}"

  mkdir -p "$path"
  git init -q -b main "$path"
  git -C "$path" config user.email test@example.com
  git -C "$path" config user.name 'Test User'
  echo "test" > "$path/README.md"
  git -C "$path" add README.md
  git -C "$path" commit -qm "init"
  if [[ "$branch" != "main" ]]; then
    git -C "$path" checkout -qb "$branch"
  fi
}

register_pane() {
  local pane_id="$1"
  local label="${2:-}"
  if [[ -n "$label" ]]; then
    set_pane_title "$pane_id" "$label"
  fi
  controller register "$pane_id" >/dev/null
}

mark_agent() {
  local pane_id="$1"
  local provider="${2:-unknown}"
  local label="${3:-}"
  if [[ -n "$label" ]]; then
    set_pane_title "$pane_id" "$label"
  fi
  controller mark-agent "$pane_id" "$provider" >/dev/null
}

mark_pane() {
  local pane_id="$1"
  local label="${2:-}"
  if [[ -n "$label" ]]; then
    set_pane_title "$pane_id" "$label"
  fi
  controller mark-pane "$pane_id" >/dev/null
}

set_pane_status() {
  local pane_id="$1"
  local status="$2"
  local text="${3:-}"
  controller set-status "$pane_id" "$status" "$text" >/dev/null
}

set_pane_title() {
  local pane_id="$1"
  local title="$2"
  tmux_test select-pane -t "$pane_id" -T "$title"
}

snapshot_output() {
  controller snapshot
}

status_output() {
  controller status
}

session_option() {
  tmux_test show-option -qv -t "$TEST_SESSION_ID" "$1"
}

pane_window_id() {
  tmux_test display-message -p -t "$1" '#{window_id}'
}

active_pane_in_window() {
  tmux_test display-message -p -t "$1" '#{pane_id}'
}

list_session_window_names() {
  tmux_test list-windows -t "$TEST_SESSION_ID" -F '#{window_name}'
}

session_window_count() {
  tmux_test list-windows -t "$TEST_SESSION_ID" | wc -l | tr -d ' '
}

wait_until() {
  local command="$1"
  local timeout_seconds="${2:-3}"
  local interval="${3:-0.05}"
  local deadline
  deadline="$(python3 - <<PY
import time
print(time.time() + float(${timeout_seconds}))
PY
)"

  while true; do
    if eval "$command"; then
      return 0
    fi
    python3 - <<PY
import time
if time.time() >= float(${deadline}):
    raise SystemExit(1)
time.sleep(float(${interval}))
PY
    if [[ "$?" -ne 0 ]]; then
      return 1
    fi
  done
}
