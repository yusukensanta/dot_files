# Zsh Configuration

Modular config, auto-loaded by `~/.zshrc` in filename order (`*.zsh` glob,
sorted) — drop a new file in and it's picked up with no edits to the
loader. Prefix it with the two-digit number matching what it does; the
gaps below are deliberately left for future files of that kind.

| Range | Purpose | Current files | Load-order constraint |
|---|---|---|---|
| `00-09` | Environment: PATH, umask, XDG dirs | `00-env.zsh` | Must precede `02-plugins.zsh` — defines `DOTFILES_BREW_PREFIXES`, which that file's zsh-abbr loop reads |
| `00-09` | Shell options and behavior | `01-options.zsh` | None known |
| `00-09` | Plugin loading (sheldon, zsh-abbr) | `02-plugins.zsh` | Must follow `00-env.zsh`; must precede anything using `abbr`, `zsh-defer`, or fzf-tab (`03`, `20`, `30`, `40`) |
| `00-09` | Completion system (`compinit`) | `03-completion.zsh` | Must follow `02-plugins.zsh` — needs zsh-completions' `$fpath` addition first |
| `00-09` | fzf-tab completion styling | `04-fzf-tab.zsh` | None — tolerates either side of `compinit`, per its own comment |
| `10-19` | Terminal chrome (title bar, mouse) | `10-terminal.zsh` | **None — tested** (moved to first and last in the load order, no change in behavior) |
| `20-29` | Keybindings and ZLE widgets | `20-keybindings.zsh` | Must follow `02-plugins.zsh` (fzf-tab, for `^I` capture elsewhere) |
| `30-39` | zsh-abbr abbreviations | `30-abbreviations.zsh` | Must follow `02-plugins.zsh` (`abbr` command) |
| `40-49` | Tool activation (mise, zoxide, starship, fzf) | `40-tools.zsh` | Must follow `02-plugins.zsh` (`zsh-defer`, fzf-tab) |
| `50-59` | Utility shell functions | `50-functions.zsh` | **None — tested** (moved to first in the load order, no change in behavior) |

The two "tested" rows were verified by actually sourcing each file first
and last in the sequence and confirming identical behavior both ways —
not just an absence of a known dependency. The others are "none known"
rather than "none" on principle: real but *undiscovered* dependencies are
exactly the failure mode a numbering convention exists to prevent, so
don't take an unmarked cell as a license to move a file freely — verify
first, the way the two tested ones were.

Their position in the `10`/`50` bands is still worth keeping even though
nothing enforces it: the number is also a category label (terminal chrome,
utility functions), and losing that for no functional gain would make a
future file harder to place correctly.

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
