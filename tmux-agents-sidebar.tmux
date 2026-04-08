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
  tmux bind-key "$@" "$key" run-shell "AGENTS_SIDEBAR_NOTIFY=1 AGENTS_SIDEBAR_SESSION='#{session_id}' AGENTS_SIDEBAR_PANE='#{pane_id}' AGENTS_SIDEBAR_WINDOW='#{window_id}' AGENTS_SIDEBAR_CLIENT_TTY='#{client_tty}' $CONTROLLER_Q $command"
}

set_default_option @agents_sidebar_order "orch plan impl review docs"
set_default_option @agents_sidebar_width 45
set_default_option @agents_sidebar_wide_window_name_default "agents-sidebar"
set_default_option @agents_sidebar_done_ttl 20
set_default_option @agents_sidebar_auto_compact_on_narrow 1
set_default_option @agents_sidebar_auto_compact_width 180

bind_agent_key m compact
bind_agent_key M wide
bind_agent_key N new
bind_agent_key a focus-sidebar
bind_agent_key ] next -r
bind_agent_key [ prev -r
bind_agent_key Down next -r
bind_agent_key Up prev -r
bind_agent_key Tab toggle-last

tmux bind-key x confirm-before -p "kill pane #P? (y/n)" "run-shell 'AGENTS_SIDEBAR_NOTIFY=1 AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' AGENTS_SIDEBAR_CLIENT_TTY='\''#{client_tty}'\'' $CONTROLLER_Q kill-current'"

tmux set-hook -g after-kill-pane "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q repair; AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q save-wide-layout'"
tmux set-hook -g after-split-window "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q save-wide-layout'"
tmux set-hook -g after-select-layout "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q save-wide-layout'"
tmux set-hook -g window-layout-changed "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q save-wide-layout'" 2>/dev/null || true
tmux set-hook -g client-resized "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' AGENTS_SIDEBAR_CLIENT_TTY='\''#{client_tty}'\'' $CONTROLLER_Q maybe-auto-compact; AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q maintain-sidebar-width'" 2>/dev/null || true
tmux set-hook -g client-session-changed "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' AGENTS_SIDEBAR_CLIENT_TTY='\''#{client_tty}'\'' $CONTROLLER_Q maybe-auto-compact; AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q maintain-sidebar-width'" 2>/dev/null || true
tmux set-hook -g pane-exited "run-shell -b 'AGENTS_SIDEBAR_SESSION='\''#{session_id}'\'' AGENTS_SIDEBAR_PANE='\''#{pane_id}'\'' AGENTS_SIDEBAR_WINDOW='\''#{window_id}'\'' $CONTROLLER_Q repair'" 2>/dev/null || true
