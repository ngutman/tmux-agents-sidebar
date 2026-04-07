# tmux-agents-sidebar

A tmux plugin for compact multi-agent workflows.

It gives you:
- a compact sidebar UI with separate `Agents` and `Panes` sections
- fast switching between managed panes
- compact mode that keeps inactive panes in a detached tmux store session instead of visible helper windows
- pane labels derived from cwd / git branch context
- optional Pi integration for pane-border activity indicators and sidebar row status

<p align="center">
  <video src="assets/demo.mov" controls muted playsinline width="100%">
    <a href="assets/demo.mov">Watch the demo video</a>
  </video>
</p>

[Watch the demo video](assets/demo.mov)

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

Required:
- `tmux`
- `bash`
- `python3`

Optional:
- `git` for branch-aware pane labels
- [TPM](https://github.com/tmux-plugins/tpm)
- [Pi](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent) for pane activity indicators and richer agent status

## Installation with TPM

If you are using a published GitHub copy of this repository, add it to your TPM plugin list:

```tmux
set -g @plugin '<owner>/tmux-agents-sidebar'
run '~/.tmux/plugins/tpm/tpm'
```

Then press `prefix + I`.

TPM will install the plugin to:

```text
~/.tmux/plugins/tmux-agents-sidebar/
```

The plugin entrypoint is:

```text
~/.tmux/plugins/tmux-agents-sidebar/tmux-agents-sidebar.tmux
```

## Manual / local installation

For local development, testing, or a direct clone without TPM:

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
- `prefix N` — create a new managed pane
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
~/projects/tmux-agents-sidebar/scripts/agents-sidebar repair
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus <name>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus-keep-sidebar <name>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar next
~/projects/tmux-agents-sidebar/scripts/agents-sidebar next-keep-sidebar
~/projects/tmux-agents-sidebar/scripts/agents-sidebar prev
~/projects/tmux-agents-sidebar/scripts/agents-sidebar prev-keep-sidebar
~/projects/tmux-agents-sidebar/scripts/agents-sidebar toggle-last
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus-sidebar
~/projects/tmux-agents-sidebar/scripts/agents-sidebar focus-right
~/projects/tmux-agents-sidebar/scripts/agents-sidebar register <pane-id>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar mark-agent <pane-id> [provider]
~/projects/tmux-agents-sidebar/scripts/agents-sidebar mark-pane <pane-id>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar set-status <pane-id> <status> [text]
~/projects/tmux-agents-sidebar/scripts/agents-sidebar clear-status <pane-id>
~/projects/tmux-agents-sidebar/scripts/agents-sidebar list-entries
~/projects/tmux-agents-sidebar/scripts/agents-sidebar list-agents
~/projects/tmux-agents-sidebar/scripts/agents-sidebar snapshot
~/projects/tmux-agents-sidebar/scripts/agents-sidebar cleanup-dead
~/projects/tmux-agents-sidebar/scripts/agents-sidebar refresh
~/projects/tmux-agents-sidebar/scripts/agents-sidebar status
```

## Configuration

Session or global tmux options you may want to override:

```tmux
set -g @agents_sidebar_width 45
set -g @agents_sidebar_order 'orch plan impl review docs'
set -g @agents_sidebar_done_ttl 20
set -g @agents_sidebar_wide_window_name_default 'agents-sidebar'
```

Notes:
- the default sidebar width is `45`
- labels are derived live from pane title, cwd, git branch, and command/provider heuristics
- labels are made unique automatically when multiple panes would otherwise collide
- branch labels are derived from each pane's own working directory, not from a shared tmux variable
- manual pane naming is currently disabled; use pane titles or cwd/branch context instead

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
