# Neovim Keymap Reference

**Leader key**: `,` (comma)
**Local leader**: `\` (backslash) — buffer/filetype-scoped mappings only (e.g. octo.nvim's PR/issue/review buffers)
**Neovim version**: 0.12.6

**Design notes** (why these bindings, not defaults):
- Leader is `,` not `\` — one-key reach vs pinky-stretch to the corner key. `<space>` is a separate, deliberate namespace (window nav, code actions, diagnostics), not merged with leader. Trade-off: this also nops vim's built-in `,` (repeat last `f`/`F`/`t`/`T`, reversed — the counterpart to `;`) in Normal and Visual mode (`x`, not `v`: Select mode, used by snippet placeholders, still types `,`), with nothing bound in its place. Accepted as worth it for the one-key leader reach; `;` alone (repeat forward) still works.
- Local leader is `\` (the freed-up old leader key) — kept distinct from leader specifically because octo.nvim ships ~80 `<localleader>` mappings scoped to its own buffers, several of which reuse the same 2-char suffix as unrelated global leader bindings (e.g. `ca`, `rr`, `rc`, `nr`, `nd`, `dc`) with completely different meaning. Same prefix for both would make those collide in muscle memory even though they never collide at runtime.
- No number-row keys used in any shortcut — slower to reach than letter/symbol keys. Git-conflict's "none" action uses `cn`/`,gxn`, not the plugin's default digit-based `c0`.
- `<C-h/j/k/l>` do direct window-focus switching (1 chord) as the primary bind; `<space>w{h,j,k,l}` kept as a fallback alias.
- blink.cmp completion nav uses `<C-p>`/`<C-n>` (vim's own native insert-completion convention: p=prev, n=next) — not `<C-l>`/`<C-k>`, which had directions backwards relative to vim's j/k up/down sense.
- Git conflict-resolution keys live under `,gx*` (the conflict list is `,gxl`), separate from `,gc*` which is commit-only — avoids one prefix meaning two unrelated things.
- `<C-b>` is never bound to anything (e.g. an alternate-buffer toggle) — it's the prefix key for tmux and other terminal multiplexers, so it never reaches Neovim when running inside one. Buffer next/prev use Neovim's default `]b`/`[b` instead (see Buffer Management below).
- Prefer Neovim's defaults to a custom key for the same job: tab pages are `gt`/`gT`/`:tabnew`, tags `<C-]>`/`<C-t>` and `]t`/`[t`/`]T`/`[T`, buffers `]b`/`[b`, signature help `<C-s>` (insert) — none of those keys is rebound to something else. The deliberate exception is `<C-l>` (window nav, above); its default job, clearing the search highlight, moved to `<Esc>`.
- No key is both a mapping and a prefix of longer mappings (e.g. lazy.nvim is `,L`, not `,l`, because `,lr`/`,li` exist): such a key only fires after `timeoutlen`.
- Visual-mode mappings use mode `x`, never `v`: `v` also covers Select mode, where a snippet placeholder must take typed characters as text.

---

## Built-in Defaults (Neovim 0.12+)

These keymaps are provided by Neovim — no config needed.

| Key | Mode | Action |
|-----|------|--------|
| `K` | n | Hover information (LSP) |
| `grn` | n | Rename symbol (LSP) |
| `grr` | n | Show references (LSP) |
| `gra` | n, v | Code action (LSP) |
| `gri` | n | Go to implementation (LSP) |
| `grt` | n | Go to type definition (LSP) |
| `grx` | n | Run codelens (LSP) |
| `gO` | n | Document symbols (LSP) |
| `<C-s>` | i | Signature help (LSP) |
| `[d` | n | Previous diagnostic |
| `]d` | n | Next diagnostic |
| `<C-w>d` | n | Diagnostic float |
| `<C-]>` / `<C-t>` | n | Go to definition (LSP tagfunc) / back |
| `]t` / `[t` / `]T` / `[T` | n | Next / prev / last / first tag |
| `]b` / `[b` | n | Next / prev buffer (redirected to barbar's order, see Buffer Management) |
| `gt` / `gT` | n | Next / prev tab page |
| `gcc` | n | Toggle comment line |
| `gc` | v | Toggle comment selection |

---

## General

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<C-Up>` | n | Increase window height | keymaps.lua |
| `<C-Down>` | n | Decrease window height | keymaps.lua |
| `<C-Left>` | n | Decrease window width | keymaps.lua |
| `<C-Right>` | n | Increase window width | keymaps.lua |
| `<C-h>` | n | Move focus to left window (primary) | keymaps.lua |
| `<C-l>` | n | Move focus to right window (primary) | keymaps.lua |
| `<C-j>` | n | Move focus to lower window (primary) | keymaps.lua |
| `<C-k>` | n | Move focus to upper window (primary) | keymaps.lua |
| `<Esc>` | n | Clear search highlight (the default `<C-l>`'s job) | keymaps.lua |
| `<space>wh` | n | Move focus to left window (fallback) | keymaps.lua |
| `<space>wl` | n | Move focus to right window (fallback) | keymaps.lua |
| `<space>wj` | n | Move focus to lower window (fallback) | keymaps.lua |
| `<space>wk` | n | Move focus to upper window (fallback) | keymaps.lua |
| `<space>e` | n | Show diagnostic float | keymaps.lua |
| `jj` | i | Exit insert mode | keymaps.lua |
| `<C-\>` | t | Exit terminal mode | keymaps.lua |
| `<` | x | Indent left and reselect | keymaps.lua |
| `>` | x | Indent right and reselect | keymaps.lua |
| `,L` | n | Show lazy.nvim menu | lazy.lua |

> All of the above are in `lua/config/keymaps.lua`, loaded *after* `config.lazy` sets `mapleader` — this ordering matters: a `<leader>uu`-style mapping registered before `mapleader` is set silently binds to `\uu` instead (Vim expands `<leader>` at registration time, not at keypress time). This bit the config for real before the keymaps.lua split — see `,uu`/`,ud` below.

---

## Built-in Tools (0.12+)

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `,uu` | n | Undotree — toggle undo history | keymaps.lua |
| `,ud` | n | DiffTool — compare directories | keymaps.lua |

---

## LSP (all buffers with LSP attached)

Custom keymaps that supplement built-in defaults above.

| Key | Mode | Action |
|-----|------|--------|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `<space>ca` | n, x | Code action |
| `,rn` | n | Rename symbol |
| `,wa` | n | Add workspace folder |
| `,wr` | n | Remove workspace folder |
| `,wl` | n | List workspace folders |
| `,ws` | n | Workspace symbols |
| `,q` | n | Open diagnostic list |
| `,ux` | n | Toggle diagnostics |
| `,uh` | n | Toggle inlay hints (on by default where the server provides them) |

### LSP / Mason

| Key | Mode | Action |
|-----|------|--------|
| `,ma` | n | Mason open |
| `,lr` | n | LSP restart server |
| `,li` | n | LSP server info |

---

## DAP (Debugger)

| Key | Mode | Action |
|-----|------|--------|
| `,db` | n | Toggle breakpoint |
| `,dB` | n | Conditional breakpoint |
| `,dc` | n | Continue |
| `,dv` | n | Step over |
| `,di` | n | Step into |
| `,do` | n | Step out |
| `,dr` | n | Open REPL |
| `,du` | n | Toggle DAP UI |
| `,dt` | n | Terminate session |

---

## Neotest (Testing)

| Key | Mode | Action |
|-----|------|--------|
| `,nr` | n | Run nearest test |
| `,nf` | n | Run all tests in file |
| `,ns` | n | Toggle test summary panel |
| `,no` | n | Open test output |
| `,nd` | n | Debug nearest test (via DAP) |
| `[n` | n | Jump to prev failed test |
| `]n` | n | Jump to next failed test |

---

## Scala / Metals (scala, sbt, java buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `,mc` | n | Metals compile cascade |
| `,mt` | n | Metals commands palette |
| `,mi` | n | Toggle implicit arguments |
| `,nr` | n | Pick a test case and run it (Metals Test Explorer; replaces neotest's key here) |
| `,nf` | n | Pick a test suite and run it (Metals Test Explorer) |

---

## Rust / rustaceanvim (rust buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `K` | n | Hover actions (overrides LSP K) |
| `J` | n | Join lines (overrides default J) |
| `,rr` | n | Runnables |
| `,rd` | n | Debuggables |
| `,re` | n | Expand macro |
| `,rc` | n | Open Cargo.toml |
| `,rp` | n | Go to parent module |

---

## Fuzzy Finder (fzf-lua)

| Key | Mode | Action |
|-----|------|--------|
| `,to` | n | Recently opened files |
| `,tb` | n | Open buffers |
| `,/` | n | Search in current buffer |
| `,tf` | n | Files |
| `,th` | n | Help tags |
| `,tw` | n | Grep current word |
| `,tg` | n | Live grep |
| `,td` | n | Workspace diagnostics |
| `,tk` | n | Search keymaps |
| `,ts` | n | Files in buffer directory |
| `,tF` | n | Git files |
| `,tC` | n | Git commits |
| `,tS` | n | Git status |
| `,tB` | n | Git branches |
| `,tr` | n | Resume last search |
| `,tW` | n | Grep current WORD |
| `,tv` | x | Grep visual selection |
| `,tt` | n | Search TODOs (todo-comments) |

> Inside fzf-lua window: `jj` = close, `<C-c>` = abort

---

## Git

### Neogit

| Key | Mode | Action |
|-----|------|--------|
| `,gg` | n | Neogit open / status |
| `,gs` | n | Neogit status |
| `,gcm` | n | Neogit commit |
| `,gp` | n | Neogit push |
| `,gl` | n | Neogit log |
| `,gbr` | n | Neogit branch |

### Gitsigns (hunks)

| Key | Mode | Action |
|-----|------|--------|
| `,hs` | n, x | Stage hunk, or unstage a staged one (x: selected lines only) |
| `,hr` | n, x | Reset hunk (x: selected lines only) |
| `,hS` | n | Stage buffer |
| `,hR` | n | Reset buffer |
| `,hp` | n | Preview hunk |
| `,hb` | n | Blame line (current line, virtual text) |
| `,gbt` | n | Full buffer blame (split) |
| `,ht` | n | Diff this |
| `,hD` | n | Diff this `~` |
| `,hd` | n | Preview hunk inline |
| `]c` | n | Next hunk (falls back to native diff `]c` while `vim.wo.diff` is true) |
| `[c` | n | Prev hunk (falls back to native diff `[c` while `vim.wo.diff` is true) |

### Diffview

| Key | Mode | Action |
|-----|------|--------|
| `,gd` | n | Diffview open |
| `,gD` | n | Diffview close |
| `,gF` | n | File history |
| `,gH` | n | Current file history |

### Git Conflict

| Key | Mode | Action |
|-----|------|--------|
| `,gxl` | n | List all conflicts |
| `,gxo` | n | Choose ours |
| `,gxt` | n | Choose theirs |
| `,gxb` | n | Choose both |
| `,gxn` | n | Choose none |
| `]x` | n | Next conflict |
| `[x` | n | Prev conflict |

> The plugin's default buffer-local mappings (`co`/`ct`/`cb`/`c0`) are off:
> they shadow the `c` operator (`ct{char}`, `cb`, ...) in conflicted buffers.

### GitLinker

| Key | Mode | Action |
|-----|------|--------|
| `,gy` | n, x | Yank git permalink |
| `,gY` | n, x | Open git permalink in browser |

### Octo (GitHub PRs)

Requires `gh` CLI authenticated. Uses fzf-lua as picker.

| Key | Mode | Action |
|-----|------|--------|
| `,gop` | n | PR list |
| `,goc` | n | PR create |
| `,goR` | n | Review start |
| `,goS` | n | Review submit |
| `,gom` | n | PR merge |
| `,gox` | n | PR checks |

---

## Code / Formatting

| Key | Mode | Action |
|-----|------|--------|
| `,cf` | n, x | Format buffer (conform) |

---

## Trouble (diagnostics panel)

| Key | Mode | Action |
|-----|------|--------|
| `,xx` | n | Workspace diagnostics |
| `,xb` | n | Buffer diagnostics |
| `,xd` | n | LSP definitions |
| `,xr` | n | LSP references |
| `,xs` | n | Document symbols |
| `,xq` | n | Quickfix list |
| `,xl` | n | Location list |
| `,xt` | n | TODO list (todo-comments) |

---

## Aerial (code outline)

| Key | Mode | Action |
|-----|------|--------|
| `,ao` | n | Toggle outline sidebar |
| `,af` | n | Floating nav |
| `,aj` | n | Next symbol |
| `,ak` | n | Prev symbol |

---

## Treesitter Context

| Key | Mode | Action |
|-----|------|--------|
| `,uc` | n | Jump to parent scope |
| `,ut` | n | Toggle context display |

---

## TODO Comments

| Key | Mode | Action |
|-----|------|--------|
| `,xt` | n | Trouble: TODO list |
| `,tt` | n | Fzf: search TODOs |

> No `]T`/`[T` jumps: those keys are Neovim's tag navigation.

---

## Illuminate (symbol highlighting)

| Key | Mode | Action |
|-----|------|--------|
| `]u` | n | Next reference in this buffer (u = usage) |
| `[u` | n | Prev reference in this buffer |
| `<M-n>` | n | Next reference (plugin default) |
| `<M-p>` | n | Prev reference (plugin default) |
| `<M-i>` | o, x | Reference under cursor (text object, plugin default) |

> Not `]]`/`[[`: the Python, Go, Rust, Java and Markdown ftplugins map those
> buffer-locally, which would win over a global mapping. Not `]r`/`[r`: those
> are Neovim's spelling motion (next/prev rare word).
> `<M-…>` is Alt on Linux/Windows; on macOS, Option only reaches Neovim when
> the terminal sends it as Alt (Alacritty: `option_as_alt`).

---

## Folding (nvim-ufo)

| Key | Mode | Action |
|-----|------|--------|
| `zR` | n | Open all folds |
| `zM` | n | Close all folds |
| `zK` | n | Peek fold content |

---

## Flash (jump navigation)

| Key | Mode | Action |
|-----|------|--------|
| `s` | n, x, o | Jump to any visible position |
| `S` | x, o | Treesitter node select |
| `r` | o | Remote flash (apply operator at target) |
| `R` | o, x | Treesitter search |

---

## Completion (blink.cmp)

| Key | Mode | Action |
|-----|------|--------|
| `<C-p>` | i | Select previous item |
| `<C-n>` | i | Select next item |
| `<CR>` | i | Accept |

> Command line: blink.cmp's own defaults (`<Tab>` shows/inserts, `<C-y>` accepts; `<CR>` always runs the command).
| `<Tab>` | i | Snippet forward |
| `<S-Tab>` | i | Snippet backward |
| `<C-space>` | i | Show completion menu |
| `<C-e>` | i | Hide completion menu |
| `<M-e>` | i | Fast wrap (autopairs) |

---

## Oil (file manager)

| Key | Mode | Action |
|-----|------|--------|
| `<space>o` | n | Open Oil file manager |

> Inside Oil buffer:

| Key | Action |
|-----|--------|
| `<CR>` | Open entry |
| `-` | Go to parent |
| `_` | Open CWD |
| `` ` `` | cd to dir |
| `~` | Tab-cd to dir |
| `<C-p>` | Preview |
| `<C-c>` | Close |
| `<C-l>` | Refresh |
| `<space>ov` | Open vertical split |
| `<space>oh` | Open horizontal split |
| `<space>ot` | Open in new tab |
| `g?` | Show help |
| `gs` | Change sort |
| `gx` | Open external |
| `g.` | Toggle hidden |
| `g\` | Toggle trash |

---

## Buffer Management (barbar.nvim)

| Key | Mode | Action |
|-----|------|--------|
| `]b` | n | Next buffer (tabline order; takes a count) |
| `[b` | n | Previous buffer (tabline order; takes a count) |
| `,bb` | n | Pick buffer |
| `,bc` | n | Close buffer |
| `,bl` | n | Last buffer |
| `,bs` | n | Select buffer |

---

## Markdown (render-markdown.nvim)

| Key | Mode | Action |
|-----|------|--------|
| `,mp` | n | Toggle inline rendering |

> Rendering is on by default. Toggles extmark-based inline rendering (headings, code blocks, tables, checkboxes).

---

## Marks (marks.nvim — default bindings)

| Key | Action |
|-----|--------|
| `m<letter>` | Set mark |
| `'<letter>` | Jump to mark |
| `dm<letter>` | Delete mark |
| `m,` | Set next available mark |
| `m;` | Toggle mark at cursor |

---

## Surround (nvim-surround — default bindings except visual)

| Key | Mode | Action |
|-----|------|--------|
| `ys{motion}{char}` | n | Add surround |
| `ds{char}` | n | Delete surround |
| `cs{old}{new}` | n | Change surround |
| `gs{char}` | v | Surround selection |

> Visual-mode surround is remapped from the plugin default (`S`) to `gs` —
> `S` in visual/operator-pending mode belongs to flash.nvim's treesitter
> select (see Flash section below); the two plugins collided on it.

---

## Snacks

| Key | Mode | Action |
|-----|------|--------|
| `,sn` | n | Show notification history |
| `,sd` | n | Dismiss all notifications |

---

## Quicker (quickfix)

> Inside quickfix buffer only:

| Key | Action |
|-----|--------|
| `>` | Expand context (2 lines before/after each result) |
| `<` | Collapse context |

> Quickfix buffer is editable — modify text and `:w` to apply changes to source files.

---

## Dropbar (winbar breadcrumbs)

| Key | Mode | Action |
|-----|------|--------|
| `,sb` | n | Pick symbol in winbar (fuzzy jump) |

> Winbar shows `File > Class > Method` at top of each window. Click any segment to open a drop-down picker.

---

## Treesitter Text Objects (built-in 0.12+)

| Key | Mode | Action |
|-----|------|--------|
| `an` | x, o | Select parent (outer) node |
| `in` | x, o | Select child (inner) node |
| `]n` | x | Select next node (Normal-mode `]n` is neotest's) |
| `[n` | x | Select prev node (Normal-mode `[n` is neotest's) |
