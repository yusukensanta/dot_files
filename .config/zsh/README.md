# Zsh Configuration

Modular config, auto-loaded by `~/.zshrc` in filename order (`*.zsh` glob,
sorted) — drop a new file in and it's picked up with no edits to the
loader. Prefix it with the two-digit number matching what it does; the
gaps below are deliberately left for future files of that kind.

| Range | Purpose | Current files |
|---|---|---|
| `00-09` | Environment: PATH, umask, XDG dirs | `00-env.zsh` |
| `00-09` | Shell options and behavior | `01-options.zsh` |
| `00-09` | Plugin loading (sheldon, zsh-abbr) | `02-plugins.zsh` |
| `00-09` | Completion system (`compinit`) | `03-completion.zsh` |
| `00-09` | fzf-tab completion styling | `04-fzf-tab.zsh` |
| `10-19` | Terminal chrome (title bar, mouse) | `10-terminal.zsh` |
| `20-29` | Keybindings and ZLE widgets | `20-keybindings.zsh` |
| `30-39` | zsh-abbr abbreviations | `30-abbreviations.zsh` |
| `40-49` | Tool activation (mise, zoxide, starship, fzf) | `40-tools.zsh` |
| `50-59` | Utility shell functions | `50-functions.zsh` |

Ordering within `00-09` matters and is load-bearing, not just cosmetic —
see the comment at the top of `02-plugins.zsh` for why it has to come
before `03-completion.zsh`, and `04-fzf-tab.zsh`'s comment for why it's
fine either side of `compinit`.

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

`REFACTORING.md` / `REFACTORING-COMPLETED.md` exist locally but aren't
tracked — they document a specific past migration (2025-11) and reference
filenames that no longer exist, kept as personal history rather than
maintained reference material.
