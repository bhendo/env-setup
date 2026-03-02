function fish_user_key_bindings
  # Enable Vi mode first
  fish_vi_key_bindings

  # Bind 'y' in visual mode to copy selection to system clipboard
  bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'

  # Optional: Bind 'yy' in normal mode to copy the entire line
  bind -M default yy 'fish_clipboard_copy; commandline -f repaint-mode'

  # Optional: Bind 'p' to paste from system clipboard
  bind -M default p fish_clipboard_paste
end
