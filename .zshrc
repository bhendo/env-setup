if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

setopt prompt_sp

# Customize to your needs...
source ${ZDOTDIR:-$HOME}/.zplug/init.zsh

zplug "agkozak/zsh-z"
zplug load


# Hombrew
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

# Path Updates
export GOPATH=${ZDOTDIR:-$HOME}/.go
export PATH=${ZDOTDIR:-$HOME}/.local/bin:/usr/local/sbin:$GOPATH/bin:$PATH

# AWS Vault
export AWS_VAULT_PROMPT=osascript
export AWS_VAULT_KEYCHAIN_NAME=login

# Editor
export EDITOR=vim

# X11
export DISPLAY=:0

# Alias
alias whatsmyip='dig +short myip.opendns.com @resolver1.opendns.com'

prompt_context() {
    emojis=("⚡️" "🔥" "💀" "👑" "😎" "🐸" "🐵" "🦄" "🌈" "🍻" "🚀" "💡" "🎉" "🔑" "🌙")
    RAND_EMOJI_N=$(( $RANDOM % ${#emojis[@]} + 1))
    prompt_segment black default "${emojis[$RAND_EMOJI_N]} "
}

prompt_dir() {
  prompt_segment blue black ' %(5~|%-1~/…/%3~|%4~) '
}

