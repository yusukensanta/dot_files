# dot_files

Personal dotfiles for zsh, Neovim, tmux, Alacritty, and Starship — shared across WSL/Linux and Windows dev machines.

## Contents

```
.config/nvim/       Neovim config (lazy.nvim, LSP, DAP, treesitter, etc.)
.config/zsh/        Modular zsh config, loaded in numeric order (00-env, 10-plugins, ...)
.config/sheldon/     Sheldon zsh plugin manager config
.config/starship.toml Starship prompt config (Tokyo Night preset)
.tmux.conf           tmux config
.zshrc               zsh entrypoint, sources .config/zsh/*
alacritty/           Alacritty terminal config (used on Windows)
scripts/             Install and sync helper scripts
```

## Setup on a new machine

```bash
git clone git@github.com:yusukensanta/dot_files.git ~/dot_files
cd ~/dot_files

# Install base packages, language runtimes (asdf), and tools
./scripts/install_libraries.sh

# Install zsh-abbr, starship, sheldon, and sheldon plugins
./scripts/install_zsh_tools.sh

# Copy configs from the repo into $HOME
./scripts/sync_to_win.sh
```

`install_libraries.sh` assumes Ubuntu/Debian (apt) and installs core CLI tools, fish + fisher, asdf with several language plugins, Docker, and a few Rust tools via cargo.

`install_zsh_tools.sh` installs zsh-abbr, starship, and sheldon via Homebrew (falling back to curl/cargo installers where possible).

## Syncing changes

- `scripts/sync_to_win.sh [--dry-run]` — copy configs **from this repo to `$HOME`** (and to the Windows-native Alacritty/Neovim locations under `/mnt/c/...` when run from WSL). Use this after pulling changes.
- `scripts/sync_here.sh [--dry-run]` — copy configs **from `$HOME` back into this repo**. Use this after editing configs locally, before committing.

Both scripts use `rsync -a --delete`, so run with `--dry-run` first if unsure.

## Notes

- Secrets, SSH/GPG keys, shell history, and caches are excluded via `.gitignore` and never synced into the repo.
- Windows-specific paths in the sync scripts assume a particular user profile path and may need adjusting for other machines.

## License

MIT — see [LICENSE](LICENSE).
