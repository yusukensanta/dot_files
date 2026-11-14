# dot_files

Personal dotfiles for zsh, Neovim, tmux, Alacritty, and Starship — shared across WSL, native Linux, and macOS dev machines.

## Contents

```
.config/nvim/       Neovim config (lazy.nvim, LSP, DAP, treesitter, etc.)
.config/zsh/        Modular zsh config, loaded in numeric order (00-env, 02-plugins, ...)
.config/zsh/local.d/ Host-specific/private zsh extensions, auto-loaded, untracked (gitignored)
.config/sheldon/     Sheldon zsh plugin manager config
.config/starship/    Starship prompt config (Tokyo Night preset) + AWS/GCloud session segments
.config/git/         Shared, identity-free git settings (delta, pull.rebase, ...)
.tmux.conf           tmux config
claude/              Claude Code user-scope config: CLAUDE.md, statusline script, statusLine setting
.zshrc               zsh entrypoint, sources .config/zsh/*
alacritty/           Alacritty terminal config (synced to the Windows-native path under WSL, ~/.config/alacritty elsewhere)
scripts/             Install and sync helper scripts
```

## Extending zsh config

`.zshrc` auto-loads every `*.zsh` file directly in `.config/zsh/`, sorted by
filename — no edits needed to pick up a new one. Prefix it with a two-digit
number to control load order (`00-env`, `02-plugins`, `20-keybindings`, ...).
Plugins load before completion (`03-completion`) on purpose — see the
comment at the top of `02-plugins.zsh`.

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

## Using this on a work machine

Everything shared is identity-free; everything that differs per machine goes
in an untracked local file that the sync scripts never touch.

| What | Shared (tracked) | Per-machine (untracked) |
|------|------------------|-------------------------|
| zsh | `.config/zsh/*.zsh` | `.config/zsh/local.d/*.zsh` |
| Neovim | `.config/nvim` | `lua/local/init.lua`, `lua/local/plugins/*.lua` |
| tmux | `.tmux.conf` | `~/.tmux.conf.local` |
| git | `.config/git/config` | `~/.gitconfig` (wins over the shared file) |
| ssh | — | `~/.ssh/config` (never tracked; see below) |

**Disable personally licensed AI tools (Copilot, CopilotChat, blink-copilot).**
Create `~/.config/zsh/local.d/work.zsh`:

```zsh
export DOTFILES_NO_PERSONAL_AI=1
```

Neovim reads it at startup (`lua/helpers/ai.lua`); restart the shell and nvim.
To drop any other plugin on one machine, add a spec to
`~/.config/nvim/lua/local/plugins/work.lua`, e.g.
`return { { "folke/flash.nvim", enabled = false } }` (merged by plugin name).

**Git identity.** `sync_to_host.sh` writes only `~/.config/git/config` and
never touches `~/.gitconfig`. Put identity, signing, and credential helpers in
`~/.gitconfig`; to split work and personal by directory:

```gitconfig
[user]
  name = Your Name
  email = personal@example.com
[includeIf "gitdir:~/work-repos/"]
  path = ~/.gitconfig-work   # user.email, user.signingkey, ...
```

**ssh.** Host entries, IPs, and keys are deliberately not in this repo. Keep
`~/.ssh/config` per machine; to keep work hosts separate, add
`Include ~/.ssh/config.d/*` at the **top** of it and put work hosts in
`~/.ssh/config.d/work`.

**Tool install.** `install_libraries.sh` installs Docker, fish, and several
cargo tools; skim it before running on a managed machine.

## Claude Code (user scope)

`claude/` holds the parts of `~/.claude` worth sharing across machines:
`CLAUDE.md`, `statusline-command.sh`, and `statusline.json` (just the
`statusLine` key of `settings.json`). `sync_to_host.sh` copies the first two
and **merges** the key into `~/.claude/settings.json` with `jq`; everything
else in that file (permissions, plugins, model, ...) is left exactly as it is,
and the previous file is backed up first. `sync_here.sh` does the reverse and
only ever reads the `statusLine` key out of `settings.json`. Requires `jq`.

This repo is public: keep anything private (tokens, internal hostnames,
employer details) out of `claude/CLAUDE.md`.

## Syncing changes

- `scripts/sync_to_host.sh [--dry-run] [--yes]` — copy configs **from this repo to `$HOME`**. Works on WSL, native Linux, and macOS: on WSL it additionally mirrors Alacritty/Neovim configs out to the Windows-native locations (auto-detected, no hardcoded paths); on native Linux/macOS it syncs Alacritty's config to the XDG path instead. Use this after pulling changes.
- `scripts/sync_here.sh [--dry-run] [--yes]` — copy configs **from `$HOME` back into this repo**. Use this after editing configs locally, before committing.

Both scripts use `rsync -a --delete`, which is destructive by nature (anything on the
destination not present in the source gets removed). To keep that safe:
- They prompt for confirmation before touching anything — pass `--yes` to skip the
  prompt (e.g. for automation), or `--dry-run` to preview with no changes at all.
- Anything they would delete or overwrite is moved into a timestamped backup dir
  first (`$HOME/.dotfiles-sync-backup/<timestamp>/`) instead of being destroyed —
  printed at the end of the run if anything was actually backed up.

## Notes

- Secrets, SSH/GPG keys, shell history, and caches are excluded via `.gitignore` and never synced into the repo.
- The Windows user profile path (for WSL-only Alacritty/Neovim syncing) is auto-detected via `cmd.exe`/`wslpath`, not hardcoded.

## License

MIT — see [LICENSE](LICENSE).
