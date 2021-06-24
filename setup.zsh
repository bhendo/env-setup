#!/bin/zsh
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

echo "Install Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Install cli tools"
brew install \
fzf \
reattach-to-user-namespace \
starship \
tmux \
tokei \
vim \
zoxide \
zsh-completions \
zsh-history-substring-search

echo "Configuring zsh"
mkdir -p "${ZDOTDIR:-$HOME}/.config"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/config_files/zshrc > ${ZDOTDIR:-$HOME}/.zshrc
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/config_files/starship.toml > ${ZDOTDIR:-$HOME}/.config/starship.toml
$(brew --prefix)/opt/fzf/install --all
chmod -R go-w $(brew --prefix)/share
source  ${ZDOTDIR:-$HOME}/.zshrc
echo "Done"

echo "Configuring tmux"
git clone --recursive https://github.com/gpakosz/.tmux.git "${ZDOTDIR:-$HOME}/.tmux"
ln -s "${ZDOTDIR:-$HOME}/.tmux/.tmux.conf" "${ZDOTDIR:-$HOME}/.tmux.conf"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/config_files/tmux.conf.local > ${ZDOTDIR:-$HOME}/.tmux.conf.local
echo "Done"

echo "Configuring vim"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/config_files/vimrc > ${ZDOTDIR:-$HOME}/.vimrc
vi +PlugInstall +GoInstallBinaries +qall
echo "Done"

