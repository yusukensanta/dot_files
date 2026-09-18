# Neovim Keymap Reference

**Leader key**: `,` (comma)
**Local leader**: `\` (backslash) — buffer/filetype-scoped mappings only (e.g. octo.nvim's PR/issue/review buffers)
**Neovim version**: 0.12.3

**Design notes** (why these bindings, not defaults):
- Leader is `,` not `\` — one-key reach vs pinky-stretch to the corner key. `<space>` is a separate, deliberate namespace (window nav, code actions, diagnostics), not merged with leader. Trade-off: this also nops vim's built-in `,` (repeat last `f`/`F`/`t`/`T`, reversed — the counterpart to `;`) in Normal and Visual mode, with nothing bound in its place. Accepted as worth it for the one-key leader reach; `;` alone (repeat forward) still works.
- Local leader is `\` (the freed-up old leader key) — kept distinct from leader specifically because octo.nvim ships ~80 `<localleader>` mappings scoped to its own buffers, several of which reuse the same 2-char suffix as unrelated global leader bindings (e.g. `ca`, `rr`, `rc`, `nr`, `nd`, `dc`) with completely different meaning. Same prefix for both would make those collide in muscle memory even though they never collide at runtime.
- No number-row keys used in any shortcut — slower to reach than letter/symbol keys. Git-conflict's "none" action uses `cn`/`,gxn`, not the plugin's default digit-based `c0`.
- `<C-h/j/k/l>` do direct window-focus switching (1 chord) as the primary bind; `<space>w{h,j,k,l}` kept as a fallback alias.
- blink.cmp completion nav uses `<C-p>`/`<C-n>` (vim's own native insert-completion convention: p=prev, n=next) — not `<C-l>`/`<C-k>`, which had directions backwards relative to vim's j/k up/down sense.
- Git conflict-resolution keys live under `,gx*` (alongside the existing `,gx` conflict list), separate from `,gc*` which is commit-only — avoids one prefix meaning two unrelated things.

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
| `gcc` | n | Toggle comment line |
| `gc` | v | Toggle comment selection |

---

## General

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<C-p>` | n | Tab previous | options.lua |
| `<C-n>` | n | Tab next | options.lua |
| `<C-t>` | n | Tab new | options.lua |
| `<C-Up>` | n | Increase window height | options.lua |
| `<C-Down>` | n | Decrease window height | options.lua |
| `<C-Left>` | n | Decrease window width | options.lua |
| `<C-Right>` | n | Increase window width | options.lua |
| `<C-h>` | n | Move focus to left window (primary) | options.lua |
| `<C-l>` | n | Move focus to right window (primary) | options.lua |
| `<C-j>` | n | Move focus to lower window (primary) | options.lua |
| `<C-k>` | n | Move focus to upper window (primary) | options.lua |
| `<space>wh` | n | Move focus to left window (fallback) | options.lua |
| `<space>wl` | n | Move focus to right window (fallback) | options.lua |
| `<space>wj` | n | Move focus to lower window (fallback) | options.lua |
| `<space>wk` | n | Move focus to upper window (fallback) | options.lua |
| `<space>e` | n | Show diagnostic float | options.lua |
| `jj` | i | Exit insert mode | options.lua |
| `<C-\>` | t | Exit terminal mode | options.lua |
| `<` | v | Indent left and reselect | options.lua |
| `>` | v | Indent right and reselect | options.lua |
| `,l` | n | Show lazy.nvim menu | lazy.lua |

---

## Built-in Tools (0.12+)

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `,uu` | n | Undotree — toggle undo history | options.lua |
| `,ud` | n | DiffTool — compare directories | options.lua |

---

## LSP (all buffers with LSP attached)

Custom keymaps that supplement built-in defaults above.

| Key | Mode | Action |
|-----|------|--------|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `L` | n | Signature help |
| `<M-l>` | i | Signature help (insert) |
| `<space>ca` | n, v | Code action |
| `,rn` | n | Rename symbol |
| `,wa` | n | Add workspace folder |
| `,wr` | n | Remove workspace folder |
| `,wl` | n | List workspace folders |
| `,ds` | n | Document symbols |
| `,ws` | n | Workspace symbols |
| `,lf` | n, v | Format document / selection (LSP) |
| `,q` | n | Open diagnostic list |
| `,dd` | n | Toggle diagnostics |

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
| `[t` | n | Jump to prev failed test |
| `]t` | n | Jump to next failed test |

---

## Scala / Metals (scala, sbt, java buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `,mc` | n | Metals compile cascade |
| `,mt` | n | Metals commands palette |
| `,mi` | n | Toggle implicit arguments |

---

## Rust / rustaceanvim (rust buffers only)

| Key | Mode | Action |
|-----|------|--------|
| `K` | n | Hover actions (overrides LSP K) |
| `J` | n | Join lines (overrides default J) |
| `,ca` | n | Rust code action |
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
| `,tv` | v | Grep visual selection |
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
| `,hs` | n | Stage hunk |
| `,hr` | n | Reset hunk |
| `,hS` | n | Stage buffer |
| `,hu` | n | Undo stage hunk |
| `,hR` | n | Reset buffer |
| `,hp` | n | Preview hunk |
| `,hb` | n | Blame line (current line, virtual text) |
| `,gbt` | n | Full buffer blame (split) |
| `,ht` | n | Diff this |
| `,hD` | n | Diff this `~` |
| `,hd` | n | Toggle deleted |
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
| `,gx` | n | List all conflicts |
| `,gxo` | n | Choose ours |
| `,gxt` | n | Choose theirs |
| `,gxb` | n | Choose both |
| `,gxn` | n | Choose none |
| `]x` | n | Next conflict |
| `[x` | n | Prev conflict |

> Default mappings also active: `co` ours, `ct` theirs, `cn` none, `cb` both
> (all single-letter keys chosen to avoid the number row — see Design Notes)

### GitLinker

| Key | Mode | Action |
|-----|------|--------|
| `,gy` | n, v | Yank git permalink |
| `,gY` | n, v | Open git permalink in browser |

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
| `,cf` | n, v | Format buffer (conform) |

---

## Copilot Chat

| Key | Mode | Action |
|-----|------|--------|
| `,cc` | n, v | CopilotChat toggle |
| `,cx` | n, v | CopilotChat reset |
| `,cq` | n, v | Quick chat prompt |
| `,cp` | n, v | Select prompt template |
| `,cm` | n, v | Select model |

> Inside CopilotChat: `<CR>` submit (n), `<C-s>` submit (i), `q` close (n), `<C-c>` close (i), `<S-Tab>` complete

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
| `]T` | n | Next TODO comment |
| `[T` | n | Prev TODO comment |
| `,xt` | n | Trouble: TODO list |
| `,tt` | n | Fzf: search TODOs |

---

## Illuminate (symbol highlighting)

| Key | Mode | Action |
|-----|------|--------|
| `]]` | n | Next reference |
| `[[` | n | Prev reference |

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
| `,bn` | n | Next buffer |
| `,bp` | n | Previous buffer |
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
| `v + an` | v | Select around node |
| `v + in` | v | Select inner node |
| `]n` | n | Jump to next node |
| `[n` | n | Jump to prev node |
