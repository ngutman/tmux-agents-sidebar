# AGENTS.md

## Purpose

`tmux-agents-sidebar` is a tmux plugin for compact multi-agent workflows.

It provides:
- a compact sidebar with separate `Agents` and `Panes` sections
- fast switching between managed panes
- compact mode backed by a detached tmux store session
- wide mode restoration back into a normal even-horizontal layout
- optional Pi integration for richer agent activity and pane-border indicators

## Read this first

When working in this repository, start with:
1. `README.md` — public-facing overview, installation, commands, configuration
2. `docs/development.md` — repo layout, checks, and local development flow
3. `docs/pi.md` — optional Pi integration details
4. `CONTRIBUTING.md` — contributor expectations and validation steps

## Important files

- `tmux-agents-sidebar.tmux` — tmux plugin entrypoint and key bindings
- `plugin.tmux` — compatibility wrapper
- `scripts/agents-sidebar` — shell controller and tmux state management
- `scripts/agents-sidebar.py` — interactive sidebar UI
- `integrations/pi/agents-sidebar-status.ts` — optional Pi integration
- `tests/` — shell integration tests and UI smoke tests
- `run_tests` — test runner

## Agent Notes

- Keep the public docs in sync with the actual command surface and installation flow.
- Preserve both manual installation and TPM-style loading.
- Keep compact and wide mode behavior compatible and repairable.
- Preserve saved wide layouts when switching to compact, and fall back safely if compact mode changes pane membership.
- Avoid slow per-refresh logic in the sidebar; responsiveness matters.
- Labels are derived live from pane state; manual pane naming is currently disabled.
- Branch labels are derived per pane from that pane's working directory.
- Sidebar width defaults to `45` unless a current sidebar width has been persisted in tmux options.
- When changing commands, defaults, or state semantics, update `README.md` and relevant docs.
- Before finishing substantial changes, run:
  - `./run_tests`
  - `bash -n tmux-agents-sidebar.tmux plugin.tmux run_tests scripts/agents-sidebar tests/test_*.sh tests/helpers/test_lib.sh`
  - `python3 -m py_compile scripts/agents-sidebar.py`
