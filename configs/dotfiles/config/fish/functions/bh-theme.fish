function bh-theme --description 'Toggle dark/light across ghostty, nvim, and claude'
    set -l mode $argv[1]
    if test -z "$mode"
        if defaults read -g AppleInterfaceStyle >/dev/null 2>&1
            set mode light
        else
            set mode dark
        end
    end
    if not contains -- $mode dark light
        echo 'usage: bh-theme [dark|light]' >&2
        return 1
    end

    # macOS appearance drives ghostty (light:/dark: theme pair) and nvim (auto-dark-mode.nvim)
    set -l want_dark false
    test $mode = dark; and set want_dark true
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $want_dark" >/dev/null

    # claude live-reloads settings.json; sed the symlink target so the link survives
    set -l settings (readlink -f ~/.claude/settings.json)
    if test $mode = dark
        sed -i '' 's/"theme": "light-ansi"/"theme": "dark-ansi"/' $settings
    else
        sed -i '' 's/"theme": "dark-ansi"/"theme": "light-ansi"/' $settings
    end
end
