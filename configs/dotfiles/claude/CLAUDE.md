# System notes

macOS (Apple Silicon), fish shell, Homebrew at `/opt/homebrew`.

## Tool versions are managed by mise

Python, node, ruby, go, rust, uv, terraform, etc. come from
`~/.config/mise/config.toml`. Don't install language toolchains ad-hoc
(no `brew install python`, no `npm install -g`, no `pip install --user`).

## Python: always use uv

- Run scripts: `uv run script.py` (never bare `python script.py`)
- Add deps: `uv add <pkg>` (never `pip install`)
- One-off tools: `uvx <tool>`

## Shell snippets for the user to run

Default interactive shell is fish. When suggesting commands the user
will paste, stick to POSIX or call out fish-specific syntax.

## Writing to Brian: the conversation register

The voice guide at `~/code/github.com/bhendo/my-voice/VOICE.md` defines a
conversation register that governs chat replies and any message written to
Brian, in every project:

- No em-dashes; use commas, colons, semicolons, periods, or parentheses.
- No hype vocabulary and nothing else from the guide's hard-ban list
  ("delve", "crucial", "game-changer", "revolutionize", "landscape" as
  filler, "it's not just X, it's Y").
- Size claims to their evidence; no amplified marketing figures.
- Lead with the consequence or the finding; put paths, identifiers, and
  mechanics after it, or leave them out.
- Use no shorthand that has not been introduced in the conversation.
- Contractions are fine; genuine questions are fine.

For prose deliverables (essays, reports, docs), use the my-voice plugin's
write skill (`/my-voice:write`) and the full guide.
