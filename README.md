# Environment Setup

Install common tools and configure fish, zsh, tmux, neovim

## Quick Start

```bash
./setup.zsh
```

The script runs under zsh (the macOS default), so no shell changes are
needed beforehand. It will:

- install Homebrew and everything in `Brewfile` (including ghostty)
- symlink dotfiles for zsh, fish, starship, ghostty, mise, tmux, and Claude Code
- register fish in `/etc/shells` and make it your default shell
  (prompts for your password via `sudo`/`chsh`)
- install rustup (via the official installer), then language toolchains
  via `mise` (rust nightly + rust-analyzer included — see
  `configs/dotfiles/config/mise/config.toml`)
- clone tmux and neovim configs

Re-running is safe: existing symlinks are replaced in place and any real
files found in the way are backed up with a `.bak.<timestamp>` suffix.
The script stops on the first error (`set -e`), so a clean "... done" at
the end means everything converged.

## Fish functions

Custom functions in `configs/dotfiles/config/fish/functions/` are prefixed
`bh-`, so typing `bh` and pressing Tab lists all of them. Two kinds keep
their required names instead: wrappers that shadow a command (`claude`) and
fish hooks (`fish_user_key_bindings`).

## Tool audit

`bh-tool-audit` (a fish function wrapping `scripts/tool-audit.py`) reports when
each brew package and global mise tool was last used, based on shell history,
binary access times, and Spotlight app metadata. Optional arguments `brew` or
`mise` limit the report to one section.

## Git hooks

`setup.zsh` installs a global pre-commit hook via `core.hooksPath` that scans
staged changes with [gitleaks](https://github.com/gitleaks/gitleaks) and blocks
the commit if any secrets are detected. If `gitleaks` is not installed the
hook prints a warning and lets the commit through — it is installed via
`mise` (see `configs/dotfiles/config/mise/config.toml`).

The hook lives at `configs/dotfiles/githooks/pre-commit`, symlinked to
`~/.githooks`. If a repo has its own `.git/hooks/pre-commit`, this hook chains
to it so per-repo hooks still run.

### Bypassing the hook

For a single commit where the finding is a false positive:

```bash
git commit --no-verify
```
