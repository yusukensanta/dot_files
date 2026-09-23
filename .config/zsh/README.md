# Zsh Configuration

Modular config, auto-loaded by `~/.zshrc` in filename order (`*.zsh` glob,
sorted) — drop a new file in and it's picked up with no edits to the
loader. Prefix it with the two-digit number matching what it does; the
gaps below are deliberately left for future files of that kind.

| Range | Purpose | Current files | Load-order constraint |
|---|---|---|---|
| `00-09` | Environment: PATH, umask, XDG dirs | `00-env.zsh` | **Must precede `02-plugins.zsh` — tested** (fresh-`$HOME` run: `02`'s zsh-abbr loop reads `DOTFILES_BREW_PREFIXES`, defined here; without it, `abbr` never loads at all). Same reason it must precede `40-tools.zsh`: both call `_dotfiles_cached_source`, also defined here, to cache sheldon/starship/fzf's generated init scripts instead of re-forking those binaries every shell start. *Not* shown to need to be absolute-first: on this machine mise/starship/fzf/fd/rg/zoxide were already reachable without this file's PATH additions — that's this machine's inherited PATH being complete already, not a guarantee, so don't rely on it |
| `00-09` | Shell options and behavior | `01-options.zsh` | **None — tested** (moved to last in the load order: history vars, `AUTO_CD`, `KEYTIMEOUT`, and `^A`/`^E` bindings from `20-keybindings.zsh` all unaffected) |
| `00-09` | Plugin loading (sheldon, zsh-abbr) | `02-plugins.zsh` | **Must follow `00-env.zsh`, must precede `03`/`30` — tested**, both with a fresh `$HOME` (no persisted state to mask the effect): reversed vs. `03`, 242 of 2008 completion functions silently failed to index (compinit's fpath scan missed zsh-completions); reversed vs. `30`, `gs` never expands (no persisted `abbr` store to fall back to, unlike on a machine with real prior usage, which masks this) |
| `00-09` | Completion system (`compinit`) | `03-completion.zsh` | Must follow `02-plugins.zsh` — see above, tested from that side |
| `00-09` | fzf-tab completion styling | `04-fzf-tab.zsh` | **None — tested** (moved to the absolute first position, before even `00`: its zstyle rules still register correctly — zstyle is a settings registry consulted later, at first *use*, not at definition time, so it was never going to be order-sensitive) |
| `10-19` | Terminal chrome (title bar, mouse) | `10-terminal.zsh` | **None — tested** (moved to first and last in the load order, no change in behavior) |
| `20-29` | Keybindings and ZLE widgets | `20-keybindings.zsh` | **None — tested** (moved to the absolute first position). This *used* to depend on `02-plugins.zsh` (fzf-tab, for `^I` capture) — no longer true since that logic moved into `40-tools.zsh`; the constraint moved with it, this file didn't inherit it |
| `30-39` | zsh-abbr abbreviations | `30-abbreviations.zsh` | Must follow `02-plugins.zsh` (`abbr` command) — see above, tested from that side |
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
