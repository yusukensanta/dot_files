local options = {
  autoread = true,
  modeline = false,
  -- Backup and file handling
  backup = false,                              -- Don't create backup files
  backupskip = { "/tmp/*" },                   -- Skip backup for these paths
  swapfile = false,                            -- Don't create swap files
  undofile = true,                             -- Enable persistent undo
  writebackup = false,                         -- Don't create backup before overwriting

  -- Visual appearance
  background = "dark", -- Set background theme
  cmdheight = 1,       -- More room for messages
  conceallevel = 0,    -- Don't hide characters (markdown, etc.)
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
  numberwidth = 4, -- Width of line number column
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
  winblend = 0, -- Window transparency
  wrap = false, -- No wrapping for code

  -- Search and completion
  completeopt = { "menu", "menuone", "noselect" }, -- Enhanced completion
  hlsearch = true,                                            -- Highlight search results
  ignorecase = true,                                          -- Case insensitive search
  incsearch = true,                                           -- Show search matches as you type
  smartcase = true,                                           -- Smart case sensitivity
  wildmenu = true,                                            -- Enhanced command line completion
  wildmode = "longest:full,full",                             -- Command completion behavior
  wildoptions = "pum",                                        -- Use popup for wildmenu

  -- Indentation and formatting
  autoindent = true,  -- Copy indent from current line
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

  -- Encoding and shell
  fileencoding = "utf-8", -- File encoding
  shell = "zsh",          -- Set shell

  -- Clipboard
  clipboard = "unnamedplus", -- Use system clipboard


  -- Misc
  breakindent = true,  -- Wrapped lines maintain indent level
  --colorcolumn = "120",                    -- Show ruler at 80 and 120 characters
  confirm = true,      -- Confirm before closing unsaved files
  foldenable = true,   -- Enable folding
  foldlevel = 99,      -- Start with all folds open
  foldlevelstart = 99, -- Start with all folds open
  -- foldmethod / foldexpr / foldtext intentionally omitted:
  -- nvim-ufo (ufo.lua) owns fold management and resets foldmethod to "manual" internally.
  -- Setting foldmethod = "expr" here conflicts with ufo and corrupts the fold column.
  grepformat = "%f:%l:%c:%m", -- Format for grep output
  grepprg = "rg --vimgrep", -- Use ripgrep for better search
  inccommand = "nosplit", -- Show live preview of substitutions
  laststatus = 3, -- Global statusline
  linebreak = true, -- Wrap at word boundaries
  showbreak = "↪ ", -- Character to show at wrapped lines
  spelllang = { "en" }, -- Spell checking language
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



-- Global diagnostic display config.
-- Python's ty/ruff/basedpyright source tagging is folded in here (scoped by
-- diagnostic.bufnr's filetype) instead of a separate FileType python
-- vim.diagnostic.config() call, since diagnostic.config() has no buffer
-- scoping and would otherwise deep-merge into (and permanently mutate) this
-- global config for every filetype once any Python file was opened.
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    source = "if_many",
    format = function(diagnostic)
      local bufnr = diagnostic.bufnr
      if bufnr and vim.bo[bufnr].filetype == "python" then
        local source = diagnostic.source or "[N/A]"
        local tag = ""
        if source == "ty" then
          tag = "[TYPE] "
        elseif source == "ruff" then
          tag = "[LINT] "
        elseif source == "basedpyright" then
          tag = "[COMP] "
        end
        return tag .. diagnostic.message
      end
      return diagnostic.message
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

-- Filetype detection for types Neovim doesn't know by default
vim.filetype.add({
  extension = { gotmpl = "gotmpl" },
  pattern = { [".*%.tmpl"] = "gotmpl" },
})

-- General keymaps and autocmds intentionally live elsewhere, not here:
-- see config/keymaps.lua and config/autocmds.lua respectively.
