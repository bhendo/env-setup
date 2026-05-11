# Environment Setup

Install common tools and configure zsh, tmux, neovim

## Quick Start

### Set zsh as your default shell

To change zsh to your default shell run

```bash
chsh -s $(which zsh)
```

### Run setup

```bash
./setup.zsh
```

## Git hooks

`setup.zsh` installs a global pre-commit hook via `core.hooksPath` that scans
staged changes with [gitleaks](https://github.com/gitleaks/gitleaks) and blocks
the commit if any secrets are detected. If `gitleaks` is not installed the
hook prints a warning and lets the commit through — install it via `Brewfile`
to get real protection.

The hook lives at `configs/dotfiles/githooks/pre-commit`, symlinked to
`~/.githooks`. If a repo has its own `.git/hooks/pre-commit`, this hook chains
to it so per-repo hooks still run.

### Bypassing the hook

For a single commit where the finding is a false positive:

```bash
git commit --no-verify
```
