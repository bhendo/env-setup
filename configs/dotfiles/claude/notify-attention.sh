#!/bin/bash

[ -z "$TMUX_PANE" ] && exit 0

case "$1" in
  set)   tmux set-window-option -t "$TMUX_PANE" @waiting 1 ;;
  clear) tmux set-window-option -t "$TMUX_PANE" -u @waiting ;;
  *)     exit 2 ;;
esac
