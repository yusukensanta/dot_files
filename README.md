# dot_files

<!-- portfolio-badge -->
[![Portfolio Docs](https://img.shields.io/badge/docs-yusukensanta.github.io-blue?style=flat-square)](https://yusukensanta.github.io/projects/dot_files/)
<!-- portfolio-badge -->

Personal dotfiles for zsh, Neovim, tmux, Alacritty, and Starship — shared across WSL, native Linux, and macOS dev machines.

## Contents

```
.config/nvim/       Neovim config (lazy.nvim, LSP, DAP, treesitter, etc.)
.config/zsh/        Modular zsh config, loaded in numeric order (00-env, 10-plugins, ...)
.config/zsh/local.d/ Host-specific/private zsh extensions, auto-loaded, untracked (gitignored)
.config/sheldon/     Sheldon zsh plugin manager config
.config/starship/    Starship prompt config (Tokyo Night preset) + AWS/GCloud session segments
.tmux.conf           tmux config
.zshrc               zsh entrypoint, sources .config/zsh/*
alacritty/           Alacritty terminal config (synced to the Windows-native path under WSL, ~/.config/alacritty elsewhere)
scripts/             Install and sync helper scripts
```

## Extending zsh config

`.zshrc` auto-loads every `*.zsh` file directly in `.config/zsh/`, sorted by
filename — no edits needed to pick up a new one. Prefix it with a two-digit
number to control load order (`00-env`, `10-plugins`, `20-keybindings`, ...).

For host-specific or private config (secrets, work-only aliases, machine
overrides) that shouldn't be committed, drop `*.zsh` files into
`.config/zsh/local.d/` instead — it's gitignored and loaded last, after
everything else. `sync_here.sh`/`sync_to_host.sh` skip that directory
entirely, so it's never overwritten or deleted by a sync in either direction.

## Setup on a new machine

```bash
git clone git@github.com:yusukensanta/dot_files.git ~/dot_files
cd ~/dot_files

# Install base packages, language runtimes (mise), and tools
./scripts/install_libraries.sh

# Install zsh-abbr, starship, sheldon, and sheldon plugins
./scripts/install_zsh_tools.sh

# Copy configs from the repo into $HOME
./scripts/sync_to_host.sh
```

`install_libraries.sh` supports Ubuntu/Debian (apt) and macOS (Homebrew), installing core CLI tools, fish + fisher, mise with several language runtimes, Docker, and a few Rust tools via cargo.

`install_zsh_tools.sh` installs zsh-abbr, starship, and sheldon via Homebrew (falling back to curl/cargo installers where possible).

## Syncing changes

- `scripts/sync_to_host.sh [--dry-run]` — copy configs **from this repo to `$HOME`**. Works on WSL, native Linux, and macOS: on WSL it additionally mirrors Alacritty/Neovim configs out to the Windows-native locations (auto-detected, no hardcoded paths); on native Linux/macOS it syncs Alacritty's config to the XDG path instead. Use this after pulling changes.
- `scripts/sync_here.sh [--dry-run]` — copy configs **from `$HOME` back into this repo**. Use this after editing configs locally, before committing.

Both scripts use `rsync -a --delete`, so run with `--dry-run` first if unsure.

## Notes

- Secrets, SSH/GPG keys, shell history, and caches are excluded via `.gitignore` and never synced into the repo.
- The Windows user profile path (for WSL-only Alacritty/Neovim syncing) is auto-detected via `cmd.exe`/`wslpath`, not hardcoded.

## License

MIT — see [LICENSE](LICENSE).
