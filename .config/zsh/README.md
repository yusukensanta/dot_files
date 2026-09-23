# Zsh Configuration

Modular config, auto-loaded by `~/.zshrc` in filename order (`*.zsh` glob,
sorted) — drop a new file in and it's picked up with no edits to the
loader. Prefix it with the two-digit number matching what it does; the
gaps below are deliberately left for future files of that kind.

| Range | Purpose | Current files | Load-order constraint |
|---|---|---|---|
| `00-09` | Environment: PATH, umask, XDG dirs, OS detection | `00-env.zsh` | **Must precede `02-plugins.zsh`, `04-fzf-tab.zsh`, `30-abbreviations.zsh` — tested** (fresh-`$HOME` run): `02`/`40` call `_dotfiles_cached_source`, defined here; `30`'s deferred loader reads `DOTFILES_BREW_PREFIXES` to find zsh-abbr, also defined here; `04` reads `$DOTFILES_OS` to pick `ls`'s color flag — silently falls back to the GNU flag rather than erroring if skipped, so this one degrades wrong instead of breaking outright, worth keeping correct anyway. *Not* shown to need to be absolute-first: on this machine mise/starship/fzf/fd/rg/zoxide were already reachable without this file's PATH additions — that's this machine's inherited PATH being complete already, not a guarantee, so don't rely on it |
| `00-09` | Shell options and behavior | `01-options.zsh` | **None — tested** (moved to last in the load order: history vars, `AUTO_CD`, `KEYTIMEOUT`, and `^A`/`^E` bindings from `20-keybindings.zsh` all unaffected) |
| `00-09` | Plugin loading (sheldon) | `02-plugins.zsh` | **Must follow `00-env.zsh`, must precede `03` — tested** with a fresh `$HOME`: reversed vs. `03`, 242 of 2008 completion functions silently failed to index (compinit's fpath scan missed zsh-completions). No longer touches zsh-abbr at all (moved to `30`, see below) |
| `00-09` | Completion system (`compinit`) | `03-completion.zsh` | Must follow `02-plugins.zsh` — see above, tested from that side |
| `00-09` | fzf-tab completion styling | `04-fzf-tab.zsh` | **Must follow `00-env.zsh`** (`$DOTFILES_OS`, see above) — **the rest untested-but-inherited from before**: this file's other settings are zstyle registrations, consulted lazily at first *use*, so they weren't order-sensitive when this row was last verified at the absolute-first position; re-verify from scratch if that matters, since it hasn't been re-tested since the `$DOTFILES_OS` line was added |
| `10-19` | Terminal chrome (title bar, mouse) | `10-terminal.zsh` | **None — tested** (moved to first and last in the load order, no change in behavior) |
| `20-29` | Keybindings and ZLE widgets | `20-keybindings.zsh` | **None — tested** (moved to the absolute first position). This *used* to depend on `02-plugins.zsh` (fzf-tab, for `^I` capture) — no longer true since that logic moved into `40-tools.zsh`; the constraint moved with it, this file didn't inherit it |
| `30-39` | zsh-abbr: load + sync abbreviations | `30-abbreviations.zsh` | **Must follow `00-env.zsh`** (`DOTFILES_BREW_PREFIXES`, to find zsh-abbr itself — this file now sources the plugin, not `02`) — **tested** by skipping `02` entirely: `zsh-defer` then never gets defined, and the file's own fallback runs the whole load synchronously instead, still correctly registering all 28 abbreviations. Following `02` is worth keeping for the (untested-by-necessity, since deferred behavior needs a real interactive/ZLE session) perf win: zsh-defer delays sourcing zsh-abbr until the first idle tick after the prompt draws, since that's ~15ms on its own — the most expensive single thing this shell does at startup, more than sheldon+starship+fzf combined — verified via a pty session that `abbr` is unavailable immediately after the prompt but has synced all 28 entries by the next command |
| `40-49` | Tool activation (mise, zoxide, starship, fzf) | `40-tools.zsh` | Must follow `02-plugins.zsh` for `zsh-defer` to be used (falls back to synchronous mise activation otherwise — degrades, doesn't break). The fzf `^I`-fallback-capture concern in this file's own comment is real in principle but weaker than stated: tested moving this before `02` and the *end result* `^I` binding was identical either way (fzf-tab's own load rebinds it regardless) — the risk is narrower, in fzf's own internal `**`-trigger fallback specifically, which a non-interactive test can't cleanly observe. Keeping the safe order costs nothing, so it stays |
| `50-59` | Utility shell functions | `50-functions.zsh` | **None — tested** (moved to first in the load order, no change in behavior) |

Every row above is now either tested (moved to an extreme position and
checked, ideally with a throwaway `$HOME` so persisted state — an abbr
store, a `.zcompdump` cache — can't mask a real dependency) or points at
one that was. Don't take that as a standing guarantee, though: re-verify
before relying on it if anything in these files changes.

The `10`/`20`/`50` files' positions are still worth keeping even though
nothing enforces them: the number is also a category label (terminal
chrome, keybindings, utility functions), and losing that for no
functional gain would make a future file harder to place correctly.

`local.d/*.zsh` loads last, after everything above, for host-specific or
private config (secrets, work-only aliases) — not tracked in git.

## Reference docs

- **[ZLE Widgets Reference](ZLE-WIDGETS-REFERENCE.md)** — every ZLE widget
  available to bind, if you're adding a new keybinding in
  `20-keybindings.zsh` and want to know what's out there.
- Run `zsh-keys` in a shell for what's *actually* bound right now (defined
  in `50-functions.zsh`) — kept in sync with `20-keybindings.zsh` by hand,
  so if you add or remove a binding there, update that heredoc too.
- Run `zsh-doctor` / `zsh-benchmark` (also in `50-functions.zsh`) to check
  startup time.
