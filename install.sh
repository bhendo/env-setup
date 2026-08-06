#!/usr/bin/env bash
# Codespaces/Linux dotfiles installer. GitHub Codespaces runs this
# automatically when this repo is selected under
# github.com/settings/codespaces → "Automatically install dotfiles".
# Scope: Claude Code configs only — the full macOS setup remains setup.zsh.
# Idempotent; safe to re-run anywhere (including macOS).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SRC="$DIR/configs/dotfiles/claude"

mkdir -p "$HOME/.claude"
for f in CLAUDE.md settings.json statusline-command.sh notify-attention.sh; do
  ln -sf "$CLAUDE_SRC/$f" "$HOME/.claude/$f"
done
echo "dotfiles: linked claude configs into ~/.claude"
