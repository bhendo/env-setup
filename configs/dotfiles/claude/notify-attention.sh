#!/bin/bash
# Toggle tmux window flags that signal Claude Code state.
#   @waiting → 🔔  needs attention now
#   @cold    → ❄️  prompt cache has gone cold (~5min idle)

[ -z "$TMUX_PANE" ] && exit 0

set_flag()   { tmux set-window-option -t "$TMUX_PANE" "@$1" 1; }
clear_flag() { tmux set-window-option -t "$TMUX_PANE" -u "@$1"; }

case "$1" in
  attention)        set_flag waiting ;;
  fresh)            set_flag waiting; clear_flag cold ;;
  notify)
    # Notification hook: idle_prompt → ❄️, anything else (permission_prompt …) → 🔔
    type=$(jq -r '.notificationType // empty' 2>/dev/null)
    if [ "$type" = "idle_prompt" ]; then set_flag cold; else set_flag waiting; fi
    ;;
  seen)             clear_flag waiting ;;
  reset)            clear_flag waiting; clear_flag cold ;;
  *) exit 2 ;;
esac
