function fish_user_key_bindings
  if command -q fzf
    fzf --fish | source
  end
  # Enable Vi mode first
  fish_vi_key_bindings

  # Bind 'y' in visual mode to copy selection to system clipboard
  bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'

  # Optional: Bind 'yy' in normal mode to copy the entire line
  bind -M default yy 'fish_clipboard_copy; commandline -f repaint-mode'

  # Optional: Bind 'p' to paste from system clipboard
  bind -M default p fish_clipboard_paste

  # F7 (ghostty sends it on cmd+opt+t) toggles dark/light everywhere
  bind -M insert f7 'bh-theme; commandline -f repaint'
  bind -M default f7 'bh-theme; commandline -f repaint'
end
