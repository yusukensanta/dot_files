# dot_files

Personal dotfiles (zsh, Neovim, tmux, Alacritty, Starship, git, Claude Code)
for WSL, native Linux and macOS. The repo is public.

## Layout

| Path | Content |
|---|---|
| `.config/`, `.zshrc`, `.zshenv`, `.tmux.conf`, `alacritty/` | Files as installed under `$HOME` |
| `claude/` | The synced parts of `~/.claude`; `claude/CLAUDE.md` is the user-scope file, not this project's |
| `claude/scripts/hagent.py` | herdr sessions and worktree cleanup (Python, standard library only) |
| `scripts/` | `install_*.sh`, `sync_to_host.sh` (repo to `$HOME`), `sync_here.sh` (`$HOME` to repo) |
| `scripts/lib/` | Shared shell code for the scripts |
| `scripts/tests/` | Tests |

## Tests

```bash
bash scripts/tests/test_sync_scripts.sh    # install and sync scripts, plus shellcheck
python3 -m unittest discover -s scripts/tests -p test_hagent.py
uvx coverage run --include=claude/scripts/hagent.py -m unittest discover -s scripts/tests -p test_hagent.py && uvx coverage report --fail-under=80
bash scripts/tests/test_zsh_startup.sh     # zsh startup correctness and timing
bash scripts/tests/test_nvim_config.sh     # Neovim config
```

Shellcheck alone: `shellcheck -S warning scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh claude/*.sh .config/starship/*.sh .config/starship/lib/*.sh`

## Conventions

- `.gitignore` ignores every `*.md`. A new tracked doc or skill needs its own
  `!path` exception there.
- A new synced file needs entries in both sync scripts, the "CLAUDE CODE" or
  matching comment in `scripts/lib/sync_common.sh`, and a test.
- Scripts must run on bash 3.2 (macOS): guard empty arrays as
  `${arr[@]+"${arr[@]}"}`.
- Tests use a throwaway `$HOME` and stubbed commands.
- Workflows declare `contents: read` and pin actions to a commit SHA with a
  `# vX.Y.Z` comment; Dependabot bumps the pins.
- Per-machine settings (`~/.claude/*.json`, `.config/zsh/local.d/`) are never
  synced or committed.
