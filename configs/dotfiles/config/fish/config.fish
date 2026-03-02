# Homebrew
set -gx HOMEBREW_NO_ANALYTICS 1
set -gx HOMEBREW_NO_INSECURE_REDIRECT 1
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_CASK_OPTS "--require-sha --appdir=~/Applications"

# Go
set -gx GOPATH $HOME/.go

# AWS Vault
set -gx AWS_VAULT_PROMPT osascript
set -gx AWS_VAULT_KEYCHAIN_NAME login

# Git
set -gx GIT_COMPLETION_CHECKOUT_NO_GUESS 1

# Editor
set -gx VISUAL nvim
set -gx EDITOR $VISUAL

# X11
set -gx DISPLAY :0

# Path
fish_add_path $HOME/.local/bin
fish_add_path $GOPATH/bin
fish_add_path $HOME/.cargo/bin
fish_add_path /opt/homebrew/bin

# Aliases
alias whatsmyip 'dig +short myip.opendns.com @resolver1.opendns.com'
alias ls lsd
alias vim nvim
alias vi nvim

# Fish configurations
set -g fish_key_bindings fish_vi_key_bindings

# Tool integrations
if status is-interactive
    mise activate fish | source
    starship init fish | source
    zoxide init fish | source
    fzf --fish | source
end
