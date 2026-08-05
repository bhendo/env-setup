#!/bin/zsh

set -e -u -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS="--require-sha --appdir=~/Applications"

echo "Installing homebrew ..."
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "  homebrew already installed, skipping"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "... done"

echo "Linking config files ..."
mkdir -p "${ZDOTDIR:-$HOME}/.config"

# Per-file symlinks (live outside ~/.config or alongside other files)
for dotFile in zshrc config/starship.toml tmux.conf.local Brewfile
do
    target="${ZDOTDIR:-$HOME}/.$dotFile"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -s "$SCRIPT_DIR/configs/dotfiles/$dotFile" "$target"
done

# Whole-directory symlinks under ~/.config (captures any new files automatically)
for configDir in fish ghostty mise
do
    target="${ZDOTDIR:-$HOME}/.config/$configDir"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -s "$SCRIPT_DIR/configs/dotfiles/config/$configDir" "$target"
done

# Claude Code config (per-file symlinks; ~/.claude holds other user state)
mkdir -p "${ZDOTDIR:-$HOME}/.claude"
for claudeFile in statusline-command.sh settings.json notify-attention.sh CLAUDE.md
do
    target="${ZDOTDIR:-$HOME}/.claude/$claudeFile"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -s "$SCRIPT_DIR/configs/dotfiles/claude/$claudeFile" "$target"
done

# Global git hooks
githooks_target="${ZDOTDIR:-$HOME}/.githooks"
if [ -L "$githooks_target" ]; then
    rm "$githooks_target"
elif [ -d "$githooks_target" ]; then
    mv "$githooks_target" "$githooks_target.bak.$(date +%Y%m%d%H%M%S)"
fi
ln -s "$SCRIPT_DIR/configs/dotfiles/githooks" "$githooks_target"
git config --global core.hooksPath "$githooks_target"
echo "... done"

echo "Installing tools ..."
brew bundle install --global
$(brew --prefix)/opt/fzf/install --all
chmod -R go-w $(brew --prefix)/share
echo "... done"

echo "Setting fish as the default shell ..."
fish_path="$(brew --prefix)/bin/fish"
if ! grep -qx "$fish_path" /etc/shells; then
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
fi
if [ "$(dscl . -read "$HOME" UserShell | awk '{print $2}')" != "$fish_path" ]; then
    chsh -s "$fish_path"
else
    echo "  fish already the default shell, skipping"
fi
echo "... done"

echo "Installing dev tools ..."
# rust (nightly + rust-analyzer) comes from mise; see config/mise/config.toml
mise install
echo "... done"

echo "Configuring tmux ..."
if [ ! -d "${ZDOTDIR:-$HOME}/.tmux/.git" ]; then
    rmdir "${ZDOTDIR:-$HOME}/.tmux" 2>/dev/null || true
    git clone --recursive https://github.com/gpakosz/.tmux.git "${ZDOTDIR:-$HOME}/.tmux"
else
    echo "  ~/.tmux already cloned, skipping"
fi
tmuxconf_target="${ZDOTDIR:-$HOME}/.tmux.conf"
if [ -L "$tmuxconf_target" ]; then
    rm "$tmuxconf_target"
elif [ -e "$tmuxconf_target" ]; then
    mv "$tmuxconf_target" "$tmuxconf_target.bak.$(date +%Y%m%d%H%M%S)"
fi
ln -s "${ZDOTDIR:-$HOME}/.tmux/.tmux.conf" "$tmuxconf_target"
echo "... done"

echo "Configuring vim ..."
if [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/.git" ]; then
    # Empty dir is okay; git clone refuses if it contains files
    rmdir "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" 2>/dev/null || true
    git clone https://github.com/bhendo/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
else
    echo "  ~/.config/nvim already cloned, skipping"
fi
echo "... done"

echo "Installing iTerm2 profile ..."
dynprofiles="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$dynprofiles"
profile_target="$dynprofiles/env-setup.json"
if [ -L "$profile_target" ]; then
    rm "$profile_target"
elif [ -e "$profile_target" ]; then
    mv "$profile_target" "$profile_target.bak.$(date +%Y%m%d%H%M%S)"
fi
ln -s "$SCRIPT_DIR/configs/iterm2-profile.json" "$profile_target"
echo "... done"
