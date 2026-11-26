# dot_files

[![install and sync scripts](https://github.com/yusukensanta/dot_files/actions/workflows/scripts.yml/badge.svg?branch=master)](https://github.com/yusukensanta/dot_files/actions/workflows/scripts.yml)
[![zsh startup (Linux)](https://github.com/yusukensanta/dot_files/actions/workflows/zsh-linux.yml/badge.svg?branch=master)](https://github.com/yusukensanta/dot_files/actions/workflows/zsh-linux.yml)
[![zsh startup (macOS)](https://github.com/yusukensanta/dot_files/actions/workflows/zsh-macos.yml/badge.svg?branch=master)](https://github.com/yusukensanta/dot_files/actions/workflows/zsh-macos.yml)

Personal dotfiles for zsh, Neovim, tmux, Alacritty, and Starship — shared across WSL, native Linux, and macOS dev machines.

- **Fast shell:** zsh startup went from 90ms to 12ms on average (WSL2, Ubuntu 24.04), and a test guards the rules that keep it there.
- **Tested in CI:** the bootstrap script runs on macOS and on bare Ubuntu 22.04, 24.04 and 26.04 containers; the install and sync scripts have their own test suite and pass shellcheck.
- **Safe syncing:** both sync directions ask first, support `--dry-run`, and back up whatever they would overwrite or delete.
- **Work-machine friendly:** shared files carry no identity; per-machine settings live in untracked local files.
- **Parallel agents:** [`hagent`](claude/scripts/hagent.py) runs Claude Code sessions per git worktree and cleans up the finished ones.

## Contents

```
.config/nvim/       Neovim config (lazy.nvim, LSP, DAP, treesitter, etc.)
.config/zsh/        Modular zsh config, loaded in numeric order (00-env, 02-plugins, ...)
.config/zsh/local.d/ Host-specific/private zsh extensions, auto-loaded, untracked (gitignored)
.config/sheldon/     Sheldon zsh plugin manager config
.config/starship/    Starship prompt config (Tokyo Night preset) + AWS/GCloud session segments
.config/git/         Shared, identity-free git settings (delta, pull.rebase, ...)
.tmux.conf           tmux config
claude/              Claude Code user-scope config: CLAUDE.md, statusline, skills, hagent
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
#    bat, eza, zoxide, starship, sheldon (+ plugins), and delta for git
./scripts/install_zsh_tools.sh

# 2. Install the remaining base packages, language runtimes (mise), and tools
./scripts/install_libraries.sh

# 3. Copy configs from the repo into $HOME
./scripts/sync_to_host.sh
```

`install_zsh_tools.sh` runs first and needs only bash. It installs zsh, git and curl; delta, the pager the shared git config uses (from cargo where apt has none, as on Ubuntu 22.04 and Debian 12); the CLI tools the zsh config uses (fzf, fd, ripgrep, bat, eza, zoxide); and starship and sheldon (plus its plugins). It uses Homebrew on macOS and apt on Debian/Ubuntu, with curl/cargo installers for starship and sheldon where apt is used; those go into `~/.local/bin`, so no sudo is needed for them. Linux does not need Homebrew: one that is installed next to apt is not used, and the zsh config does not put it on `PATH` (on a distro without apt, a Homebrew already on `PATH` is used). Re-running skips anything already installed.

zsh, fzf and sheldon have a minimum version, set in one place: `scripts/lib/min_versions.sh` (each with the reason for it). The script upgrades an older one, first through the package manager and then, for fzf and sheldon, with the project's own installer into `~/.local/bin`, so an old distro package is not a blocker and no sudo is needed for that step. The script looks commands up in the same order as the zsh config (Homebrew, `~/.cargo/bin`, `~/.local/bin`, then the rest of `PATH`), so the version it checks is that of the binary zsh will run. An fzf below the minimum has no `fzf --zsh`; the zsh config refuses to half-use it (the fzf key bindings stay off and every new shell says to update).

A step that fails (no sudo rights, a blocked download, a package this distro doesn't have) is a warning, not an abort: the remaining steps still run, the warnings are listed at the end, and the exit status is non-zero only when zsh itself is missing or a tool is still older than its minimum. The zsh config checks each tool with `command -v`, so it starts without the optional ones. Because this runs before `sync_to_host.sh`, sheldon's plugins are installed from the repo's own `plugins.toml` when the machine has none yet.

Per-machine choices for the install and sync scripts go in one untracked file, `~/.config/dot_files/install.local.sh` (see [Using this on a work machine](#using-this-on-a-work-machine)).

`install_libraries.sh` supports Ubuntu/Debian (apt) and macOS (Homebrew), installing the rest in steps: `packages` (tmux, neovim, ...), `fish` (+ fisher), `mise` (with several language runtimes; with Rust it also makes mise follow a project's `rust-toolchain.toml` and adds rust-analyzer + rust-src to the toolchain, see [Neovim: languages](#neovim-languages)), `tpm`, `docker`, `cargo` (a few Rust tools) and `neovim` (its plugins). A step that fails does not stop the others; the failed steps are listed at the end and the exit status is non-zero.

## zsh startup time

Every new shell prints `✨ ZSH loaded in <N>ms ⚡`: the time from the start of
zsh (stamped in `~/.zshenv`, so system startup files are counted) until the
prompt can be drawn. Work deferred with `zsh-defer` (mise, some
plugins) finishes just after, so it is not in that number.

CI runs the bootstrap script and these checks on macOS and, from a bare
container, on Ubuntu 22.04, 24.04 and 26.04, plus the install/sync scripts'
own test suite and shellcheck (`.github/workflows/`).

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
| tool install | `scripts/install_*.sh` | `~/.config/dot_files/install.local.sh` |
| what gets synced | `scripts/sync_*.sh` | `SYNC_SKIP` in the same file |
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

**Per-machine plugin overrides.** To drop a plugin on one machine, add a spec to
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
  sudo apt-get install -y some-work-only-tool
}
```

Names for `ZSH_TOOLS_SKIP`: `zsh git curl delta fzf fd rg bat eza zoxide
starship sheldon`. A skipped tool is not version-checked either. The file can also set
a different minimum for this machine, e.g. `MIN_VERSION_zsh=5.9`. A value given on the command line
(`ZSH_TOOLS_SKIP="eza" ./scripts/install_zsh_tools.sh`) wins over the file;
`DOTFILES_INSTALL_LOCAL=<path>` points at a different file.

`install_libraries.sh` reads the same file. It needs sudo on Linux, and two
of its steps are worth a thought on a managed machine: `docker` adds you to
the `docker` group (as good as root on that machine) and, on macOS, installs
Docker Desktop, whose license terms cover use at a company; `mise` installs
language runtimes globally. To leave steps out or pick the runtimes:

```bash
LIBRARIES_SKIP="docker"                 # steps: packages fish mise tpm docker cargo neovim
LIBRARIES_MISE_RUNTIMES="node python"   # default: go java node python ruby rust terraform sbt poetry
```

**Sync.** `SYNC_SKIP` in the same file keeps things out of both
`sync_to_host.sh` and `sync_here.sh`, e.g. on a work machine whose
`~/.claude/CLAUDE.md` comes from the employer:

```bash
SYNC_SKIP="claude"   # names: nvim zsh sheldon starship zshrc zshenv tmux git claude alacritty
```

As with `ZSH_TOOLS_SKIP`, a value given on the command line wins over the
file. A name that isn't on the list in `LIBRARIES_SKIP` or `SYNC_SKIP` stops
the run before anything is installed or copied, so a typo can't let through
the very thing it was meant to keep out.

**Using this as someone else.** The install and sync scripts read only
`$HOME`/`$USER`, with no hardcoded user or path (the WSL Alacritty config gets
the syncing user filled in). One tracked file is personal:
`claude/CLAUDE.md`, which replaces `~/.claude/CLAUDE.md` (the old one is
backed up). Change it in your fork, or keep it off with `SYNC_SKIP="claude"`.

The abbreviation list is personal too, but needs no fork: override it from
`local.d` (see Abbreviations above).

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

### Parallel sessions with herdr (`hagent`)

`claude/scripts/hagent.py` runs Claude Code sessions in
[herdr](https://herdr.dev), one per branch, and removes the git worktrees that
are no longer needed. `sync_to_host.sh` copies it with its skill, links it as
`~/.local/bin/hagent`, and writes herdr's own skill from `herdr --skill`.
Needs Python 3.10+, git and, for pull request state, `gh`.

```bash
hagent start feat/x --task "..."   # worktree + herdr workspace + Claude agent
hagent status                      # agents, sessions, last cleanup
hagent clean                       # dry run: SAFE / ASK / KEEP per worktree
hagent clean --apply               # remove the SAFE ones
hagent remove PATH --confirm TOKEN # one ASK item, as printed by `clean`
```

A worktree is a candidate when its pull request is merged or closed, or it has
been inactive for a week. It is `SAFE` only when nothing would be lost (no
uncommitted, untracked or ignored files apart from caches, no commits that only
the worktree's own reflog or refs hold, not locked, not detached) and nothing is
using it. Removing a worktree keeps the branch, except for a merged pull request
whose head equals the branch.

The token for `remove` belongs to one worktree and lapses when its HEAD or a
listed file changes. A worktree with commits that nothing else leads to is
refused until a branch holds them; `clean` prints the command. "In use" is read
from working directories in the Linux process list, so a program that reaches
into a worktree from elsewhere, or a privileged one started outside it, is not
seen.

Settings, per machine and optional, in `~/.claude/hagent.json`:

```json
{
  "roots": ["~/work"],
  "stale_days": 7,
  "cache_names": ["__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", "node_modules"],
  "auto_remove": false
}
```

Setup that the sync does not do for you:

```bash
herdr integration install claude   # lets herdr restore Claude sessions (edits settings.json)
hagent clean                       # check the verdicts first
systemctl --user daemon-reload
systemctl --user enable --now hagent-clean.timer   # Linux/WSL, daily
```

herdr shows no pop-ups by default. For the cleanup notification, add this to
`~/.config/herdr/config.toml` (it also enables herdr's own agent pop-ups;
`"terminal"` and `"system"` are the other choices), then run
`herdr server reload-config`:

```toml
[ui.toast]
delivery = "herdr"
```

The timer only reports until `"auto_remove": true`. It shows a herdr
notification when something was removed, a new item needs approval, or the run
failed; `SAFE` items alone do not notify. Runs are logged in
`~/.local/state/hagent/clean.log`. Removal works on Linux only (it reads
`/proc` to see what is in use).

## Neovim: languages

The config separates the shared editor from the languages:

- **Shared core:** `lua/plugins/{lsp,conform,treesitter,dap,neotest}.lua`.
  These plugins do the work, but name no language.
- **One file per language:** `lua/plugins/lang/<language>.lua` adds that
  language's servers, formatters, parsers, Mason packages, debugger and test
  adapter to the core through lazy.nvim `opts`. A plugin that serves only one
  language (rustaceanvim, nvim-metals, nvim-dap-python, ...) loads only for
  that language's filetype.
- **Buffer settings:** `after/ftplugin/<filetype>.lua` holds indent, spell,
  the formatter timeout and similar settings. Neovim runs these files only
  for that filetype, which it detects from the file's extension.

So a file starts only the servers and plugins of its own language. A plain
text file starts none.

| Language | Server(s) | Formats on save | Lint |
|---|---|---|---|
| Python | basedpyright, ruff | Ruff: organize imports, format | Ruff |
| Go | gopls, golangci-lint-langserver | goimports, gofumpt | golangci-lint |
| Rust | rust-analyzer (rustaceanvim) | rustfmt | clippy |
| Scala, Java | Metals (nvim-metals) | scalafmt via Metals | compiler |
| Lua | lua_ls (+ lazydev) | stylua | lua_ls |
| JS/TS, JSON | ts_ls | Biome | — |
| C/C++ | clangd | clang-format via clangd | clang-tidy |
| Shell | bash-language-server | shfmt | ShellCheck |
| Markdown | — | Prettier | — |
| YAML | yaml-language-server | Prettier | schema validation |
| TOML | Taplo | Taplo | Taplo |
| Dockerfile | dockerfile-language-server | — | the server |
| Terraform | terraform-ls | `terraform fmt` | terraform-ls |

Formatters follow the project's own config when it has one (`pyproject.toml`
/ `ruff.toml`, `biome.json`, `.editorconfig` for shfmt, `.prettierrc`,
`stylua.toml`, `.scalafmt.conf`, `.clang-format`). Without one, they use this
config's defaults. `scripts/tests/test_nvim_config.sh` checks all of the above
in headless Neovim on a machine with the plugins installed.

Each language server comes from the same toolchain the project builds with,
so the editor and `sbt`/`cargo` agree on compiler and library versions.

**Rust** (`lua/plugins/lang/rust.lua`, rustaceanvim). rust-analyzer is the one
in the project's rustup toolchain, never Mason's. That keeps the server, its
proc-macro server and the std sources (`rust-src`) on the same version as the
compiler the project pins in `rust-toolchain.toml`. Two settings make that hold,
and `install_libraries.sh` applies both:

- mise reads `rust-toolchain.toml` (`idiomatic_version_file_enable_tools`
  includes `rust`). Without it, the global `rust` sets `RUSTUP_TOOLCHAIN`,
  which overrides the project's pin.
- The toolchain has `rust-analyzer` and `rust-src`. For a project pinned to
  another toolchain, run `rustup component add rust-analyzer rust-src` once
  inside it. Neovim says so when the component is missing.

On save, rust-analyzer runs `cargo clippy --workspace --all-targets --all-features`.
Lint levels come only from the project's `[lints]` tables, so the editor and a
CI running the same command agree. It builds into `target/rust-analyzer/`, so it
never waits on, or invalidates, a `cargo build` running in a terminal.
`<leader>n…` runs tests through neotest (`cargo nextest` when installed).

**Scala** (`lua/plugins/lang/scala.lua`, nvim-metals). Metals is installed by
`:MetalsInstall` with coursier (a mise runtime here) and runs on the project's
`JAVA_HOME`.

- Run `:MetalsUpdate` after a Scala release. An older Metals can't fully
  support a newer Scala 3.
- After the build changes (a Scala version bump, a new sbt plugin), run
  `:MetalsImportBuild`. Bloop's exported build otherwise keeps compiling
  with the old settings.
- In Scala buffers, `<leader>nr` and `<leader>nf` pick a test case or suite
  and run it through Metals' already-warm build server.

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

After copying, `sync_to_host.sh` deletes the caches that were built from the
files it replaced, so nothing keeps serving the old version: the zsh init caches
in `~/.cache/zsh/` and the completion dump, sheldon's `plugins.lock`, and Neovim's
Lua bytecode cache. All of these are rebuilt by the next shell or Neovim start,
so they are not backed up. This is needed because `rsync -a` keeps the repo's
timestamps: a replaced file can look older than a cache built from the file it
replaced, so a timestamp check would not notice the change. It then brings the
installed Neovim plugins in line with the synced `lazy-lock.json` (`:Lazy restore`,
then `:Lazy clean`). All of this happens only for the parts whose content
actually changed (zsh, `.zshrc`, sheldon, Neovim; compared by checksum before
copying), so a sync that replaces nothing triggers no rebuild. Parts skipped with
`SYNC_SKIP` keep their caches, and `--dry-run` lists what it would clear without
deleting anything.

## Notes

- Secrets, SSH/GPG keys, shell history, and caches are excluded via `.gitignore` and never synced into the repo.
- The Windows user profile path (for WSL-only Alacritty/Neovim syncing) is auto-detected via `cmd.exe`/`wslpath`, not hardcoded.

## License

MIT — see [LICENSE](LICENSE).
