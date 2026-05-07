#!/bin/zsh

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS="--require-sha --appdir=~/Applications"

echo "Installing homebrew ..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "... done"

echo "Linking config files ..."
mkdir -p ${ZDOTDIR:-$HOME}/.config
mkdir -p ${ZDOTDIR:-$HOME}/.config/nvim

# Per-file symlinks (live outside ~/.config or alongside other files)
for dotFile in zshrc config/starship.toml tmux.conf.local Brewfile
do
    if [ -L ${ZDOTDIR:-$HOME}/.$dotFile ]; then
        rm ${ZDOTDIR:-$HOME}/.$dotFile
    fi
    ln -s $SCRIPT_DIR/configs/dotfiles/$dotFile ${ZDOTDIR:-$HOME}/.$dotFile
done

# Whole-directory symlinks under ~/.config (captures any new files automatically)
for configDir in fish ghostty mise
do
    target=${ZDOTDIR:-$HOME}/.config/$configDir
    if [ -L $target ]; then
        rm $target
    elif [ -d $target ]; then
        mv $target $target.bak.$(date +%Y%m%d%H%M%S)
    fi
    ln -s $SCRIPT_DIR/configs/dotfiles/config/$configDir $target
done
echo "... done"

echo "Installing tools ..."
brew bundle install --global
$(brew --prefix)/opt/fzf/install --all
chmod -R go-w $(brew --prefix)/share
echo "... done"

echo "Installing rust ..."
rustup toolchain install stable nightly
rustup default nightly
rustup component add rust-analyzer
echo "... done"

echo "Installing dev tools ..."
mise install
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
git clone https://github.com/bhendo/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
echo "... done"
