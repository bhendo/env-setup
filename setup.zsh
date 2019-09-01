#!/bin/zsh
echo "Configuring zsh"
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/.zpreztorc > ${ZDOTDIR:-$HOME}/.zpreztorc
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/.zshrc > ${ZDOTDIR:-$HOME}/.zshrc
source  ${ZDOTDIR:-$HOME}/.zshrc
zplug install
zplug load
echo "Done"

echo "Configuring tmux"
git clone --recursive https://github.com/gpakosz/.tmux.git "${ZDOTDIR:-$HOME}/.tmux"
ln -s "${ZDOTDIR:-$HOME}/.tmux/.tmux.conf" "${ZDOTDIR:-$HOME}/.tmux.conf"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/.tmux.conf.local > ${ZDOTDIR:-$HOME}/.tmux.conf.local
echo "Done"

echo "Configuring vim"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/bhendo/env-setup/master/.vimrc > ${ZDOTDIR:-$HOME}/.vimrc
vi +PlugInstall +GoInstallBinaries +qall
echo "Done"

