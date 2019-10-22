# Environment Setup

These scripts configure ZSH, TMUX, and VIM

## Quick Start

### Set zsh as your default shell

To change zsh to your default shell run
```bash
chsh -s $(which zsh)
```

### Install and configure a powerline font

If you are using a terminal without powerline fonts please besure to install one available at [https://github.com/powerline/fonts](https://github.com/powerline/fonts). Fira Mono seems as good as any.

### Install tmux locally

If you don't have access to tmux (or the latest version) run:
```bash
curl -sL --proto-redir --all,https https://raw.githubusercontent.com/bhendo/env-setup/master/install_local_tmux.zsh | zsh
```
### Instal dot files
```bash
curl -sL --proto-redir --all,https https://raw.githubusercontent.com/bhendo/env-setup/master/setup.zsh | zsh
```

### Configure .zshrc

You may need to update your paths etc. especially if you install local tmux. example:

```bash
export PATH=${PATH}:${ZDOTDIR:-$HOME}/.local/bin
```
