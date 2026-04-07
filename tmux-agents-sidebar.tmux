#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONTROLLER="$CURRENT_DIR/scripts/agents-sidebar"
CONTROLLER_Q="$(printf '%q' "$CONTROLLER")"

set_default_option() {
  local option="$1"
  local value="$2"
  local current
  current="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    tmux set-option -gq "$option" "$value"
  fi
}

bind_agent_key() {
  local key="$1"
  local command="$2"
  shift 2
  tmux bind-key "$@" "$key" run-shell "AGENTS_SIDEBAR_NOTIFY=1 AGENTS_SIDEBAR_SESSION='#{session_id}' AGENTS_SIDEBAR_PANE='#{pane_id}' $CONTROLLER_Q $command"
}

set_default_option @agents_sidebar_order "orch plan impl review docs"
set_default_option @agents_sidebar_width 45
set_default_option @agents_sidebar_wide_window_name_default "agents-sidebar"
set_default_option @agents_sidebar_done_ttl 20

bind_agent_key m compact
bind_agent_key M wide
bind_agent_key N new
bind_agent_key a focus-sidebar
bind_agent_key ] next -r
bind_agent_key [ prev -r
bind_agent_key Down next -r
bind_agent_key Up prev -r
bind_agent_key Tab toggle-last

tmux bind-key x confirm-before -p "kill pane #P? (y/n)" "run-shell 'AGENTS_SIDEBAR_NOTIFY=1 AGENTS_SIDEBAR_SESSION=\"#{session_id}\" AGENTS_SIDEBAR_PANE=\"#{pane_id}\" $CONTROLLER_Q kill-current'"

# kill-pane recovery is handled synchronously by the custom prefix-x binding.
tmux set-hook -gu after-kill-pane
