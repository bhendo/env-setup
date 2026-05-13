function tmux-cleanup-popups
    for session in (tmux list-sessions -F '#S' 2>/dev/null | string match 'popup-*')
        tmux kill-session -t $session
        and echo "killed $session"
    end
end
