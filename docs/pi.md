# Pi integration

`tmux-agents-sidebar` can optionally consume Pi lifecycle events and show them in two places:

1. the sidebar row for that Pi pane
2. the tmux pane border next to `P#{pane_index}`

## What it shows

Pi panes publish these states:
- `idle` — waiting for input
- `running` — actively processing a prompt
- `tool` — currently executing a tool
- `done` — just finished successfully (brief TTL)
- `error` — last run ended with an error

Pane-border indicator mapping:
- `[·]` — waiting
- `[●]` — running
- `[⚙]` — tool
- `[✓]` — finished
- `[✗]` — errored

## Extension file

The Pi hook lives here:

```text
integrations/pi/agents-sidebar-status.ts
```

## Setup

Link the extension into Pi's global extension directory:

```bash
mkdir -p ~/.pi/agent ~/.pi/agent/extensions
ln -sfn ~/workspace/configs/pi/agent/settings.json ~/.pi/agent/settings.json
ln -sfn ~/workspace/configs/pi/agent/extensions/minimal-footer.ts ~/.pi/agent/extensions/minimal-footer.ts
ln -sfn ~/projects/tmux-agents-sidebar/integrations/pi/agents-sidebar-status.ts ~/.pi/agent/extensions/agents-sidebar-status.ts
```

If your tmux config already uses the pane-border format documented below, reload tmux and Pi:

```bash
tmux source-file ~/.tmux.conf
```

Then inside each active Pi session:

```text
/reload
```

## tmux pane-border format

To show the indicator near the pane, include `@pi_session_indicator` in your pane-border format:

```tmux
set-window-option -g pane-border-status bottom
set-window-option -g pane-border-format '#[fg=colour51,bold]P#{pane_index}#{?@pi_session_indicator, #{@pi_session_indicator},} #[fg=colour223]#{b:pane_current_path}#{?@git_branch, #[fg=#ffff00]#{@git_branch},}#[default]'
```

The Pi extension writes these pane-local tmux options:
- `@pi_session_state`
- `@pi_session_indicator`

It also updates sidebar metadata for the current pane:
- `@agents_sidebar_kind_<paneid>`
- `@agents_sidebar_provider_<paneid>`
- `@agents_sidebar_status_<paneid>`
- `@agents_sidebar_status_text_<paneid>`
- `@agents_sidebar_last_done_<paneid>`

## State transitions

The extension uses Pi hooks like this:
- `session_start` → `idle`
- `agent_start` → `running`
- `tool_execution_start` → `tool`
- `tool_execution_end` → back to `running`
- `agent_end` → `done` or `error`
- `session_shutdown` → `idle`

`done` automatically falls back to `idle` after a short TTL.
`error` stays visible until the next run starts.
