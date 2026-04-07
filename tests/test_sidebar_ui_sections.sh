#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$CURRENT_DIR/.." && pwd)"
PYTHON_FILE="$PROJECT_ROOT/scripts/agents-sidebar.py"

python3 - "$PYTHON_FILE" <<'PY'
import importlib.util
import sys
from pathlib import Path

path = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("agents_sidebar_ui", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

Entry = module.Entry
SidebarState = module.SidebarState
SidebarApp = module.SidebarApp
ANSI_RE = module.ANSI_RE

app = SidebarApp("session", "/tmp/controller")
state = SidebarState(
    mode="compact",
    active_name="pi-bot",
    last_active_name="shellbox",
    sidebar_pane="%9",
    focus_pane="%1",
    epoch=7,
    width=48,
    height=16,
    entries=[
        Entry("pi-bot", "%1", "@1", "main", "agent", "pi", "tool", "bash", "repo", "main", "node", True),
        Entry("shellbox", "%2", "@1", "main", "pane", "shell", "idle", "", "repo", "", "zsh", False),
    ],
)
app.state = state
lines = [ANSI_RE.sub("", line) for line in app.build_lines(state)]
text = "\n".join(lines)

assert "Agents (1)" in text, text
assert "Panes (1)" in text, text
assert "pi-bot" in text, text
assert "shellbox" in text, text
assert "⚙ bash" in text, text
assert "counts a:1 p:1" in text, text
PY

echo "ok - sidebar UI renders Agents and Panes sections"
