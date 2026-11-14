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
.zshenv              Block merged into ~/.zshenv (skips Ubuntu's system compinit, stamps the startup timer)
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

# 1. Install zsh and everything its config needs to start: fzf, fd, ripgrep,
#    bat, eza, zoxide, starship, sheldon (+ plugins)
./scripts/install_zsh_tools.sh

# 2. Install the remaining base packages, language runtimes (mise), and tools
./scripts/install_libraries.sh

# 3. Copy configs from the repo into $HOME
./scripts/sync_to_host.sh
```

`install_zsh_tools.sh` runs first and needs only bash. It installs zsh, git and curl; the CLI tools the zsh config uses (fzf, fd, ripgrep, bat, eza, zoxide); and starship and sheldon (plus its plugins). It uses Homebrew when present, otherwise apt on Debian/Ubuntu, with curl/cargo installers for starship and sheldon. Without Homebrew, starship and sheldon go into `~/.local/bin`, so no sudo is needed for them. Re-running skips anything already installed.

zsh, fzf and sheldon have a minimum version, set in one place: `scripts/lib/min_versions.sh` (each with the reason for it). The script upgrades an older one, first through the package manager and then, for fzf and sheldon, with the project's own installer into `~/.local/bin`, so an old distro package is not a blocker and no sudo is needed for that step. An fzf below the minimum has no `fzf --zsh`; the zsh config refuses to half-use it (the fzf key bindings stay off and every new shell says to update).

A step that fails (no sudo rights, a blocked download, a package this distro doesn't have) is a warning, not an abort: the remaining steps still run, the warnings are listed at the end, and the exit status is non-zero only when zsh itself is missing or a tool is still older than its minimum. The zsh config checks each tool with `command -v`, so it starts without the optional ones. Because this runs before `sync_to_host.sh`, sheldon's plugins are installed from the repo's own `plugins.toml` when the machine has none yet.

Per-machine install choices go in an untracked file, `~/.config/dot_files/install.local.sh` (see [Using this on a work machine](#using-this-on-a-work-machine)).

`install_libraries.sh` supports Ubuntu/Debian (apt) and macOS (Homebrew), installing the rest: tmux, neovim, fish + fisher, mise with several language runtimes, Docker, and a few Rust tools via cargo.

## zsh startup time

Every new shell prints `✨ ZSH loaded in <N>ms ⚡`: the time from the start of
zsh (stamped in `~/.zshenv`, so system startup files are counted) until the
prompt can be drawn. Work deferred with `zsh-defer` (mise, some
plugins) finishes just after, so it is not in that number.

CI runs the bootstrap script and these checks on macOS and, from a bare
container, on Ubuntu 22.04, 24.04 and 26.04 (`.github/workflows/`).

Measured on WSL2 Ubuntu 24.04, 90ms -> 12ms average. Two rules keep it there,
and `scripts/tests/test_zsh_startup.sh` fails if either is broken:

- **`~/.zshenv` sets `skip_global_compinit=1`.** Ubuntu's `/etc/zsh/zshrc`
  otherwise runs a full `compinit` before `~/.zshrc` is read;
  `03-completion.zsh` already runs its own cached one.
- **Never read `$commands` / `${commands[x]}` at startup.** The first access
  makes zsh hash every executable on `$PATH`; under WSL that includes
  `/mnt/c/WINDOWS/system32` (~5000 files over 9p) and costs ~60ms. Use
  `command -v x` instead.

`sync_to_host.sh` merges `.zshenv` into `~/.zshenv` as a marked block and
leaves every other line (rustup, employer setup) alone. It is one-way:
`sync_here.sh` does not pull it back.

## Using this on a work machine

Everything shared is identity-free; everything that differs per machine goes
in an untracked local file that the sync scripts never touch.

| What | Shared (tracked) | Per-machine (untracked) |
|------|------------------|-------------------------|
| zsh | `.config/zsh/*.zsh` | `.config/zsh/local.d/*.zsh` |
| abbreviations | `DOTFILES_ABBRS` in `30-abbreviations.zsh` | `DOTFILES_ABBRS[...]=` in a `local.d` file |
| Neovim | `.config/nvim` | `lua/local/init.lua`, `lua/local/plugins/*.lua` |
| tmux | `.tmux.conf` | `~/.tmux.conf.local` |
| tool install | `scripts/install_zsh_tools.sh` | `~/.config/dot_files/install.local.sh` |
| git | `.config/git/config` | `~/.gitconfig` (wins over the shared file) |
| ssh | — | `~/.ssh/config` (never tracked; see below) |

**Abbreviations.** `gs` + Space (or Enter) becomes `git status` on the
command line; `abbr` lists them all. They are a plain zsh array plus two zle
widgets in `30-abbreviations.zsh`, with no plugin to install. A word expands
only in command position (start of the line, or after `;`, `|`, `&&`, ...),
and a `%` in an expansion is where the cursor lands. To change the list on
one machine, add a `local.d` file:

```zsh
DOTFILES_ABBRS[kx]='kubectx'           # add or replace
unset 'DOTFILES_ABBRS[d]'              # remove
DOTFILES_ABBRS=(gs 'git status -sb')   # or start over with your own
```

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

**Tool install.** `install_zsh_tools.sh` sources
`~/.config/dot_files/install.local.sh` if it exists (it lives outside the
repo and outside every synced directory, so nothing tracks or overwrites it):

```bash
# tools this machine must not install (curl installer, not allowed here, ...)
ZSH_TOOLS_SKIP="starship eza"

# runs last, for anything only this machine needs
install_local_extras() {
  brew install some-work-only-tool
}
```

Names for `ZSH_TOOLS_SKIP`: `zsh git curl fzf fd rg bat eza zoxide starship
sheldon`. A skipped tool is not version-checked either. The file can also set
a different minimum for this machine, e.g. `MIN_VERSION_zsh=5.9`. A value given on the command line
(`ZSH_TOOLS_SKIP="eza" ./scripts/install_zsh_tools.sh`) wins over the file;
`DOTFILES_INSTALL_LOCAL=<path>` points at a different file.

`install_libraries.sh` has no such switch: it installs Docker, fish, mise
runtimes and several cargo tools unconditionally and needs sudo, so skim it
before running on a managed machine.

**Using this as someone else.** The install and sync scripts read only
`$HOME`/`$USER`, with no hardcoded user or path. Two tracked files are
personal, and `sync_to_host.sh` copies them as they are; change them in your
fork first:

- `claude/CLAUDE.md` replaces `~/.claude/CLAUDE.md` (the old one is backed up).
- `alacritty/alacritty-wsl.toml` starts WSL as a fixed user (`wsl -u ...`).

The abbreviation list is personal too, but needs no fork: override it from
`local.d` (below).

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
