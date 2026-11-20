-- Only settings that differ from Neovim's defaults (`:help nvim-defaults`):
-- autoread, hlsearch, incsearch, autoindent, spelllang=en, ... are already on.
-- (inccommand defaults to "nosplit"; it is overridden to "split" below.)
local options = {
  modeline = false,
  -- Backup and file handling
  swapfile = false,                            -- Don't create swap files
  undofile = true,                             -- Enable persistent undo
  writebackup = false,                         -- Don't create backup before overwriting

  -- Visual appearance
  cursorcolumn = true, -- Highlight current column
  cursorline = true,   -- Highlight current line
  list = true,         -- Show invisible characters
  listchars = {
    eol = '⤶',
    space = '·',
    tab = '→ ',
    trail = '✚',
    extends = '◀',
    precedes = '▶',
    nbsp = '␣'
  },
  number = true, -- Show line numbers
  pumborder = "rounded", -- Popup menu border (0.12+)
  pumblend = 5, -- Popup menu transparency
  pumheight = 10, -- Maximum popup menu height
  winborder = "rounded", -- Default border for floating windows (0.11+); diagnostic float and mason ui inherit this
  scrolloff = 8, -- Keep 8 lines visible above/below cursor
  showmode = false, -- Don't show mode (status line handles this)
  showtabline = 2, -- Always show tab line
  sidescrolloff = 8, -- Keep 8 characters visible horizontally
  signcolumn = "yes:1", -- Always show 1-column sign area (stable width for gitsigns + marks.nvim)
  termguicolors = true, -- Enable 24-bit colors
  title = true, -- Set terminal title
  wrap = false, -- No wrapping for code

  -- Search and completion
  completeopt = { "menu", "menuone", "noselect" }, -- Enhanced completion
  ignorecase = true,                                          -- Case insensitive search
  smartcase = true,                                           -- Smart case sensitivity
  inccommand = "split",                                       -- Live :s preview with a match list in a split (default: nosplit)
  wildmode = "longest:full,full",                             -- Command completion behavior

  -- Indentation and formatting
  expandtab = true,   -- Use spaces instead of tabs
  shiftround = true,  -- Round indent to multiple of shiftwidth
  shiftwidth = 2,     -- Number of spaces for indentation
  smartindent = true, -- Smart auto indenting
  tabstop = 2,        -- Number of spaces for tab

  -- Performance and behavior
  mouse = "a",        -- Enable mouse support
  splitbelow = true,  -- Open horizontal splits below
  splitright = true,  -- Open vertical splits to the right
  timeoutlen = 300,   -- Time to wait for mapped sequence

  updatetime = 250,   -- Faster CursorHold/diagnostics response than the 4000ms default

  -- Shell
  shell = "zsh",          -- Set shell

  -- Clipboard
  clipboard = "unnamedplus", -- Use system clipboard


  -- Misc
  breakindent = true,  -- Wrapped lines maintain indent level
  --colorcolumn = "120",                    -- Show ruler at 80 and 120 characters
  confirm = true,      -- Confirm before closing unsaved files
  foldlevel = 99,      -- Start with all folds open
  foldlevelstart = 99, -- Start with all folds open
  -- foldmethod / foldexpr / foldtext intentionally omitted:
  -- nvim-ufo (ufo.lua) owns fold management and resets foldmethod to "manual" internally.
  -- Setting foldmethod = "expr" here conflicts with ufo and corrupts the fold column.
  grepprg = "rg --vimgrep", -- The default adds -uu (also searches .gitignore'd files)
  laststatus = 3, -- Global statusline
  linebreak = true, -- Wrap at word boundaries
  showbreak = "↪ ", -- Character to show at wrapped lines
  spelloptions = "camel", -- Better spell checking for code
  virtualedit = "block", -- Allow cursor beyond end of line in visual block
}

vim.opt.shortmess:append("c")

-- Disable unused providers (suppresses checkhealth warnings)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- Clipboard: WSL uses win32yank.exe to bridge to Windows clipboard — not
-- xsel/xclip, which need an X server WSL doesn't have. Matches .tmux.conf,
-- which already uses win32yank.exe for the same reason (see its comment).
-- --crlf/--lf handle the Windows-clipboard CRLF <-> buffer LF conversion
-- natively instead of a separate `tr -d '\r'` pipeline.
-- Windows native and macOS handle clipboard natively — no override needed.
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "WSL-clipboard",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 0,
  }
end



-- Global diagnostic display config. vim.diagnostic.config() has no buffer
-- scope, so per-language labels come from a buffer variable instead:
-- an after/ftplugin/ file sets vim.b.diagnostic_source_tags = { [source] =
-- "[TAG] " } (see after/ftplugin/python.lua) and the message is prefixed
-- with the tag of its source.
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    source = "if_many",
    format = function(diagnostic)
      local tags = diagnostic.bufnr and vim.b[diagnostic.bufnr].diagnostic_source_tags
      local tag = tags and diagnostic.source and tags[diagnostic.source] or ""
      return tag .. diagnostic.message
    end,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = "󰌵",
    },
  },
  severity_sort = true,
  float = { source = true }, -- border inherited from 'winborder'; "always" is a pre-0.10 leftover, type is now boolean|'if_many'
  update_in_insert = false,
})

-- Filetypes Neovim doesn't know by default are added in ftdetect/.

-- General keymaps and autocmds intentionally live elsewhere, not here:
-- see config/keymaps.lua and config/autocmds.lua respectively.
