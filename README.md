# tmux-agents-sidebar

A tmux plugin for compact multi-agent workflows.

It gives you:
- a compact sidebar UI with separate `Agents` and `Panes` sections
- fast switching between managed panes
- compact mode that keeps inactive panes in a detached tmux store session instead of visible helper windows
- pane labels derived from cwd / branch context
- optional Pi integration for pane-border activity indicators and sidebar status updates

## Features

- `wide` mode for even-horizontal multi-pane layouts
- `compact` mode with one focused pane plus a persistent sidebar
- sidebar keyboard and mouse navigation
- explicit pane classification (`mark-agent`, `mark-pane`)
- status metadata (`idle`, `running`, `tool`, `done`, `error`, `unknown`)
- Pi activity indicator near the pane border:
  - `[·]` waiting for input
  - `[●]` running
  - `[⚙]` executing a tool
  - `[✓]` just finished successfully
  - `[✗]` errored
- shell integration tests via `run_tests`

## Requirements

- `tmux`
- `bash`
- `python3`

Optional:
- [TPM](https://github.com/tmux-plugins/tpm)
- [Pi](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent) for pane activity indicators and richer agent status

## Installation with TPM

Once this repository is published, add it to your TPM plugin list:

```tmux
set -g @plugin '<your-github-user>/tmux-agents-sidebar'
run '~/.tmux/plugins/tpm/tpm'
```

Then press `prefix + I`.

The plugin entrypoint is:

```text
~/.tmux/plugins/tmux-agents-sidebar/tmux-agents-sidebar.tmux
```

## Manual / local installation

For local development or a pre-publication setup:

```bash
mkdir -p ~/.tmux/plugins
ln -sfn ~/projects/tmux-agents-sidebar ~/.tmux/plugins/tmux-agents-sidebar
```

Add this to the bottom of your tmux config:

```tmux
run-shell "$HOME/.tmux/plugins/tmux-agents-sidebar/tmux-agents-sidebar.tmux"
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Key bindings

Default key bindings:
- `prefix m` — compact mode
- `prefix M` — wide mode
- `prefix N` — create a new managed agent pane
- `prefix a` — focus the sidebar pane
- `prefix x` — compact-aware kill for the current managed pane
- `prefix ]` / `prefix [` — next / previous entry
- `prefix Down` / `prefix Up` — next / previous entry
- `prefix Tab` — toggle last active entry

## Commands

```bash
~/projects/tmux-agents-sidebar/scripts/agents-sidebar compact
~/projects/tmux-agents-sidebar/scripts/agents-sidebar wide
~/projects/tmux-agents-sidebar/scripts/agents-sidebar new
~/projects/tmux-agents-sidebar/scripts/agents-sidebar kill-current
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus <name>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus-sidebar
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus-right
~/projects/tmux-agents-sidebar/scripts/agents-sidebar register <pane-id> <name>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar mark-agent <pane-id> [provider] [label]
~/projects/tmux-agents-sidebar/scripts/agents-sidebar mark-pane <pane-id> [label]
~/projects/tmux-agents-sidebar/scripts/agents-sidebar set-status <pane-id> <status> [text]
~/projects/tmux-agents-sidebar/scripts/agents-sidebar clear-status <pane-id>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar list-entries
~/projects/tmux-agents-sidebar/scripts/agents-sidebar list-agents
~/projects/tmux-agents-sidebar/scripts/agents-sidebar snapshot
~/projects/tmux-agents-sidebar/scripts/agents-sidebar cleanup-dead
~/projects/tmux-agents-sidebar/scripts/agents-sidebar refresh
~/projects/tmux-agents-sidebar/scripts/agents-sidebar repair
~/projects/tmux-agents-sidebar/scripts/agents-sidebar status
```

## Pi integration

See [docs/pi.md](docs/pi.md).

The optional Pi extension lives at:

```text
integrations/pi/agents-sidebar-status.ts
```

## Development

Run tests from the repository root:

```bash
cd ~/projects/tmux-agents-sidebar
./run_tests
```

See [docs/development.md](docs/development.md).

## License

[MIT](LICENSE.md)
