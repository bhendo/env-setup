if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
source ${ZDOTDIR:-$HOME}/.zplug/init.zsh

zplug "agkozak/zsh-z"
zplug load

export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

# Path Updates
export GOPATH=${ZDOTDIR:-$HOME}/Development
export PATH=$GOPATH/bin:$PATH

# AWS Vault
export AWS_VAULT_PROMPT=osascript
export AWS_VAULT_KEYCHAIN_NAME=login

# Editor
export EDITOR=vim

# X11
export DISPLAY=:0

# Alias
alias whatsmyip='dig +short myip.opendns.com @resolver1.opendns.com'
