# Neovim Keymap Reference

**Leader key**: `<space>`
**Local leader**: `\` (backslash) — buffer/filetype-scoped mappings only (e.g. octo.nvim's PR/issue/review buffers)
**Neovim version**: 0.12.6

**Design notes** (why these bindings, not defaults):
- Leader is `<space>` — pressed with the thumb, so it is the cheapest key to reach (the old `,` was a middle-finger reach). `<space>` itself is nopped in Normal and Visual mode (`x`, not `v`: Select mode, used by snippet placeholders, still types a space), which only costs vim's built-in `<space>` (same as `l`). Vim's built-in `,` (repeat last `f`/`F`/`t`/`T`, reversed) is back, paired with `;`.
- Local leader is `\` (vim's default leader) — kept distinct from leader specifically because octo.nvim ships ~80 `<localleader>` mappings scoped to its own buffers, several of which reuse the same 2-char suffix as unrelated global leader bindings (e.g. `ca`, `rr`, `rc`, `nr`, `nd`, `dc`) with completely different meaning. Same prefix for both would make those collide in muscle memory even though they never collide at runtime.
- No number-row keys used in any shortcut — slower to reach than letter/symbol keys. Git-conflict's "none" action uses `cn`/`<space>gxn`, not the plugin's default digit-based `c0`.
- `<C-h/j/k/l>` do direct window-focus switching (1 chord); `<C-w>` commands cover the rest.
- blink.cmp completion nav uses `<C-p>`/`<C-n>` (vim's own native insert-completion convention: p=prev, n=next) — not `<C-l>`/`<C-k>`, which had directions backwards relative to vim's j/k up/down sense.
- Git conflict-resolution keys live under `<space>gx*` (the conflict list is `<space>gxl`), separate from `<space>gc*` which is commit-only — avoids one prefix meaning two unrelated things.
- `<C-b>` is never bound to anything (e.g. an alternate-buffer toggle) — it's the prefix key for tmux and other terminal multiplexers, so it never reaches Neovim when running inside one. Buffer next/prev use Neovim's default `]b`/`[b` instead (see Buffer Management below).
- Prefer Neovim's defaults to a custom key for the same job: tab pages are `gt`/`gT`/`:tabnew`, tags `<C-]>`/`<C-t>` and `]t`/`[t`/`]T`/`[T`, buffers `]b`/`[b`, signature help `<C-s>` (insert) — none of those keys is rebound to something else. The deliberate exception is `<C-l>` (window nav, above); its default job, clearing the search highlight, moved to `<Esc>`.
- No key is both a mapping and a prefix of longer mappings (e.g. lazy.nvim is `<space>L`, not `<space>l`, because `<space>lr`/`<space>li` exist): such a key only fires after `timeoutlen`.
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
| `<C-h>` | n | Move focus to left window | keymaps.lua |
| `<C-l>` | n | Move focus to right window | keymaps.lua |
| `<C-j>` | n | Move focus to lower window | keymaps.lua |
| `<C-k>` | n | Move focus to upper window | keymaps.lua |
| `<Esc>` | n | Clear search highlight (the default `<C-l>`'s job) | keymaps.lua |
| `<space>e` | n | Show diagnostic float | keymaps.lua |
| `jj` | i | Exit insert mode | keymaps.lua |
| `<C-\>` | t | Exit terminal mode | keymaps.lua |
| `<` | x | Indent left and reselect | keymaps.lua |
| `>` | x | Indent right and reselect | keymaps.lua |
| `<space>L` | n | Show lazy.nvim menu | lazy.lua |

> All of the above are in `lua/config/keymaps.lua`, loaded *after* `config.lazy` sets `mapleader` — this ordering matters: a `<leader>uu`-style mapping registered before `mapleader` is set silently binds to `\uu` instead (Vim expands `<leader>` at registration time, not at keypress time). This bit the config for real before the keymaps.lua split — see `<space>uu`/`<space>ud` below.
>
> `mapleader` is set to a literal `" "` in `lazy.lua`: the `<space>` notation is not expanded inside Lua strings, so `set_leader("<space>")` would make the 7-character string the leader.

---

## Built-in Tools (0.12+)

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<space>uu` | n | Undotree — toggle undo history | keymaps.lua |
| `<space>ud` | n | DiffTool — compare directories | keymaps.lua |

---

## LSP (all buffers with LSP attached)

Custom keymaps that supplement built-in defaults above.

| Key | Mode | Action |
|-----|------|--------|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `<space>ca` | n, x | Code action |
| `<space>rn` | n | Rename symbol |
| `<space>wa` | n | Add workspace folder |
| `<space>wr` | n | Remove workspace folder |
| `<space>ws` | n | Workspace symbols |
| `<space>q` | n | Open diagnostic list |
| `<space>ux` | n | Toggle diagnostics |
| `<space>uh` | n | Toggle inlay hints (on by default where the server provides them) |

### LSP / Mason

| Key | Mode | Action |
|-----|------|--------|
| `<space>ma` | n | Mason open |
| `<space>lr` | n | LSP restart server |
| `<space>li` | n | LSP server info |

---

## DAP (Debugger)

| Key | Mode | Action |
|-----|------|--------|
| `<space>db` | n | Toggle breakpoint |
| `<space>dB` | n | Conditional breakpoint |
| `<space>dc` | n | Continue |
| `<space>dv` | n | Step over |
| `<space>di` | n | Step into |
| `<space>do` | n | Step out |
| `<space>dr` | n | Open REPL |
| `<space>du` | n | Toggle DAP UI |
| `<space>dt` | n | Terminate session |

---

## Neotest (Testing)

| Key | Mode | Action |
|-----|------|--------|
| `<space>nr` | n | Run nearest test |
| `<space>nf` | n | Run all tests in file |
| `<space>ns` | n | Toggle test summary panel |
| `<space>no` | n | Open test output |
| `<space>nd` | n | Debug nearest test (via DAP) |
| `[n` | n | Jump to prev failed test |
| `]n` | n | Jump to next failed test |

---

## Scala / Metals (scala, sbt, java buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `<space>mc` | n | Metals compile cascade |
| `<space>mt` | n | Metals commands palette |
| `<space>mi` | n | Toggle implicit arguments |
| `<space>nr` | n | Pick a test case and run it (Metals Test Explorer; replaces neotest's key here) |
| `<space>nf` | n | Pick a test suite and run it (Metals Test Explorer) |

---

## Rust / rustaceanvim (rust buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `K` | n | Hover actions (overrides LSP K) |
| `J` | n | Join lines (overrides default J) |
| `<space>rr` | n | Runnables |
| `<space>rd` | n | Debuggables |
| `<space>re` | n | Expand macro |
| `<space>rc` | n | Open Cargo.toml |
| `<space>rp` | n | Go to parent module |

---

## Fuzzy Finder (fzf-lua)

| Key | Mode | Action |
|-----|------|--------|
| `<space>to` | n | Recently opened files |
| `<space>tb` | n | Open buffers |
| `<space>/` | n | Search in current buffer |
| `<space>tf` | n | Files |
| `<space>th` | n | Help tags |
| `<space>tw` | n | Grep current word |
| `<space>tg` | n | Live grep |
| `<space>td` | n | Workspace diagnostics |
| `<space>tk` | n | Search keymaps |
| `<space>ts` | n | Files in buffer directory |
| `<space>tF` | n | Git files |
| `<space>tC` | n | Git commits |
| `<space>tS` | n | Git status |
| `<space>tB` | n | Git branches |
| `<space>tr` | n | Resume last search |
| `<space>tW` | n | Grep current WORD |
| `<space>tv` | x | Grep visual selection |
| `<space>tt` | n | Search TODOs (todo-comments) |

> Inside fzf-lua window: `jj` = close, `<C-c>` = abort

---

## Git

### Neogit

| Key | Mode | Action |
|-----|------|--------|
| `<space>gg` | n | Neogit open / status |
| `<space>gs` | n | Neogit status |
| `<space>gcm` | n | Neogit commit |
| `<space>gp` | n | Neogit push |
| `<space>gl` | n | Neogit log |
| `<space>gbr` | n | Neogit branch |

### Gitsigns (hunks)

| Key | Mode | Action |
|-----|------|--------|
| `<space>hs` | n, x | Stage hunk, or unstage a staged one (x: selected lines only) |
| `<space>hr` | n, x | Reset hunk (x: selected lines only) |
| `<space>hS` | n | Stage buffer |
| `<space>hR` | n | Reset buffer |
| `<space>hp` | n | Preview hunk |
| `<space>hb` | n | Blame line (current line, virtual text) |
| `<space>gbt` | n | Full buffer blame (split) |
| `<space>ht` | n | Diff this |
| `<space>hD` | n | Diff this `~` |
| `<space>hd` | n | Preview hunk inline |
| `]c` | n | Next hunk (falls back to native diff `]c` while `vim.wo.diff` is true) |
| `[c` | n | Prev hunk (falls back to native diff `[c` while `vim.wo.diff` is true) |

### Diffview

| Key | Mode | Action |
|-----|------|--------|
| `<space>gd` | n | Diffview open |
| `<space>gD` | n | Diffview close |
| `<space>gF` | n | File history |
| `<space>gH` | n | Current file history |

### Git Conflict

| Key | Mode | Action |
|-----|------|--------|
| `<space>gxl` | n | List all conflicts |
| `<space>gxo` | n | Choose ours |
| `<space>gxt` | n | Choose theirs |
| `<space>gxb` | n | Choose both |
| `<space>gxn` | n | Choose none |
| `]x` | n | Next conflict |
| `[x` | n | Prev conflict |

> The plugin's default buffer-local mappings (`co`/`ct`/`cb`/`c0`) are off:
> they shadow the `c` operator (`ct{char}`, `cb`, ...) in conflicted buffers.

### GitLinker

| Key | Mode | Action |
|-----|------|--------|
| `<space>gy` | n, x | Yank git permalink |
| `<space>gY` | n, x | Open git permalink in browser |

### Octo (GitHub PRs)

Requires `gh` CLI authenticated. Uses fzf-lua as picker.

| Key | Mode | Action |
|-----|------|--------|
| `<space>gop` | n | PR list |
| `<space>goc` | n | PR create |
| `<space>goR` | n | Review start |
| `<space>goS` | n | Review submit |
| `<space>gom` | n | PR merge |
| `<space>gox` | n | PR checks |

---

## Code / Formatting

| Key | Mode | Action |
|-----|------|--------|
| `<space>cf` | n, x | Format buffer (conform) |

---

## Trouble (diagnostics panel)

| Key | Mode | Action |
|-----|------|--------|
| `<space>xx` | n | Workspace diagnostics |
| `<space>xb` | n | Buffer diagnostics |
| `<space>xd` | n | LSP definitions |
| `<space>xr` | n | LSP references |
| `<space>xs` | n | Document symbols |
| `<space>xq` | n | Quickfix list |
| `<space>xl` | n | Location list |
| `<space>xt` | n | TODO list (todo-comments) |

---

## Aerial (code outline)

| Key | Mode | Action |
|-----|------|--------|
| `<space>ao` | n | Toggle outline sidebar |
| `<space>af` | n | Floating nav |
| `<space>aj` | n | Next symbol |
| `<space>ak` | n | Prev symbol |

---

## Treesitter Context

| Key | Mode | Action |
|-----|------|--------|
| `<space>uc` | n | Jump to parent scope |
| `<space>ut` | n | Toggle context display |

---

## TODO Comments

| Key | Mode | Action |
|-----|------|--------|
| `<space>xt` | n | Trouble: TODO list |
| `<space>tt` | n | Fzf: search TODOs |

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
| `<C-l>` | Refresh (shadows window-right here; use `<C-w>l`) |
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
| `<space>bb` | n | Pick buffer |
| `<space>bc` | n | Close buffer |
| `<space>bl` | n | Last buffer |
| `<space>bs` | n | Select buffer |

---

## Markdown (render-markdown.nvim)

| Key | Mode | Action |
|-----|------|--------|
| `<space>mp` | n | Toggle inline rendering |

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
| `<space>sn` | n | Show notification history |
| `<space>sd` | n | Dismiss all notifications |

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
| `<space>sb` | n | Pick symbol in winbar (fuzzy jump) |

> Winbar shows `File > Class > Method` at top of each window. Click any segment to open a drop-down picker.

---

## Treesitter Text Objects (built-in 0.12+)

| Key | Mode | Action |
|-----|------|--------|
| `an` | x, o | Select parent (outer) node |
| `in` | x, o | Select child (inner) node |
| `]n` | x | Select next node (Normal-mode `]n` is neotest's) |
| `[n` | x | Select prev node (Normal-mode `[n` is neotest's) |
