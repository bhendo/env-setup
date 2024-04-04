#!/bin/zsh

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

echo "Installing homebrew ..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "... done"

echo "Linking config files ..."
mkdir -p ${ZDOTDIR:-$HOME}/.config/nvim
for dotFile in zshrc config/starship.toml tmux.conf.local config/nvim/init.vim vimrc Brewfile
do
    if [ -L ${ZDOTDIR:-$HOME}/.$dotFile ]; then
        rm ${ZDOTDIR:-$HOME}/.$dotFile
    fi
    ln -s $SCRIPT_DIR/configs/dotfiles/$dotFile ${ZDOTDIR:-$HOME}/.$dotFile
done
echo "... done"

echo "Installing tools ..."
brew bundle install --global
$(brew --prefix)/opt/fzf/install --all
chmod -R go-w $(brew --prefix)/share
echo "... done"

echo "Installing rust ..."
rustup-init -y --default-toolchain nightly
echo "... done"

echo "Configuring python ..."
asdf plugin-add python
asdf install python latest
asdf global python latest
echo "... done"

echo "Configuring tmux ..."
git clone --recursive https://github.com/gpakosz/.tmux.git "${ZDOTDIR:-$HOME}/.tmux"
if [ -L ${ZDOTDIR:-$HOME}/.tmux.conf ]; then
    rm ${ZDOTDIR:-$HOME}/.tmux.conf
fi
ln -s "${ZDOTDIR:-$HOME}/.tmux/.tmux.conf" "${ZDOTDIR:-$HOME}/.tmux.conf"
echo "... done"

echo "Configuring vim ..."
source  ${ZDOTDIR:-$HOME}/.zshrc
vi +PlugInstall +GoInstallBinaries +qall
pip install neovim
echo "... done"
