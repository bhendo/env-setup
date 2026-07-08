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

# Best-effort: pre-install the plugin the settings enable so skills exist in
# fresh codespaces. claude is on PATH by the time dotfiles run there (the
# devcontainer image installs it); elsewhere this skips quietly.
if command -v claude >/dev/null 2>&1; then
  claude plugin install superpowers@claude-plugins-official >/dev/null 2>&1 \
    && echo "dotfiles: superpowers plugin installed" \
    || echo "dotfiles: plugin install skipped (non-fatal)"
fi
