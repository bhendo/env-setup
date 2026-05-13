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
