local options = {
  autoread = true,
  -- Backup and file handling
  backup = false,                              -- Don't create backup files
  backupskip = { "/tmp/*", "/private/tmp/*" }, -- Skip backup for these paths
  swapfile = false,                            -- Don't create swap files
  undofile = true,                             -- Enable persistent undo
  writebackup = false,                         -- Don't create backup before overwriting

  -- Visual appearance
  background = "dark", -- Set background theme
  cmdheight = 1,       -- Reduced from 2 for more space (modern trend)
  conceallevel = 0,    -- Don't hide characters (markdown, etc.)
  cursorcolumn = true, -- Highlight current column
  cursorline = true,   -- Highlight current line
  list = true,         -- Show invisible characters
  listchars = {
    eol = '⤶',
    space = '·', -- Changed to less intrusive dot
    tab = '→ ', -- Added tab visualization
    trail = '✚',
    extends = '◀',
    precedes = '▶',
    nbsp = '␣' -- Added non-breaking space visualization
  },
  number = true, -- Show line numbers
  numberwidth = 4, -- Width of line number column
  pumblend = 5, -- Popup menu transparency
  pumheight = 10, -- Maximum popup menu height
  scrolloff = 8, -- Keep 8 lines visible above/below cursor
  showmode = false, -- Don't show mode (status line handles this)
  showtabline = 2, -- Always show tab line
  sidescrolloff = 8, -- Keep 8 characters visible horizontally
  signcolumn = "yes:1", -- Always show 1-column sign area (stable width for gitsigns + marks.nvim)
  termguicolors = true, -- Enable 24-bit colors
  title = true, -- Set terminal title
  winblend = 0, -- Window transparency
  wrap = false, -- Changed to false for code (modern preference)

  -- Search and completion
  completeopt = { "menu", "menuone", "noselect", "preview" }, -- Enhanced completion
  hlsearch = true,                                            -- Highlight search results
  ignorecase = true,                                          -- Case insensitive search
  incsearch = true,                                           -- Show search matches as you type (NEW)
  smartcase = true,                                           -- Smart case sensitivity
  wildmenu = true,                                            -- Enhanced command line completion (NEW)
  wildmode = "longest:full,full",                             -- Command completion behavior (NEW)
  wildoptions = "pum",                                        -- Use popup for wildmenu

  -- Indentation and formatting
  autoindent = true,  -- Copy indent from current line (NEW)
  expandtab = true,   -- Use spaces instead of tabs
  shiftround = true,  -- Round indent to multiple of shiftwidth (NEW)
  shiftwidth = 2,     -- Number of spaces for indentation
  smartindent = true, -- Smart auto indenting
  tabstop = 2,        -- Number of spaces for tab

  -- Performance and behavior
  hidden = true,      -- Allow hidden buffers (NEW)
  lazyredraw = false, -- Don't redraw during macros (can cause issues in modern nvim)
  mouse = "a",        -- Enable mouse support
  splitbelow = true,  -- Open horizontal splits below (NEW)
  splitright = true,  -- Open vertical splits to the right (NEW)
  timeoutlen = 300,   -- Time to wait for mapped sequence

  updatetime = 250,   -- Reduced from 300 for faster response

  -- Encoding and shell
  encoding = "utf-8",     -- Set encoding
  fileencoding = "utf-8", -- File encoding
  shell = "zsh",          -- Set shell

  -- Clipboard
  clipboard = "unnamedplus", -- Use system clipboard

  -- New modern options for better coding experience
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
  laststatus = 3, -- Global statusline (modern feature)
  linebreak = true, -- Wrap at word boundaries
  showbreak = "↪ ", -- Character to show at wrapped lines
  spelllang = { "en" }, -- Spell checking language
  spelloptions = "camel", -- Better spell checking for code
  virtualedit = "block", -- Allow cursor beyond end of line in visual block
}

vim.opt.shortmess:append("c")

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- Clipboard: WSL uses xsel to bridge to Windows clipboard.
-- Windows native and macOS handle clipboard natively — no override needed.
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "WSL-clipboard",
    copy = {
      ["+"] = "xsel -bi",
      ["*"] = "xsel -bi",
    },
    paste = {
      ["+"] = "xsel -bo",
      ["*"] = function() return vim.fn.system('xsel -bo | tr -d "\r"') end,
    },
    cache_enabled = 0,
  }
end



-- General Keymaps
local map = require("helpers.keys").map
-- Normal mode keymaps
map("n", "<C-p>", ":tabprev<CR>", "Options - Tab previous")
map("n", "<C-n>", ":tabnext<CR>", "Options - Tab next")
map("n", "<C-t>", ":tabnew<CR>", "Options - Tab new")
map("n", "<space>bp", ":bprevious<CR>", "Options - Buffer previous")
map("n", "<space>bn", ":bnext<CR>", "Options - Buffer next")
map("n", "<space>bd", ":bdelete<CR>", "Options - Buffer delete")
map("n", "<space>wh", "<C-w><C-h>", "Options - Move focus to left window")
map("n", "<space>wl", "<C-w><C-l>", "Options - Move focus to right window")
map("n", "<space>wj", "<C-w><C-j>", "Options - Move focus to lower window")
map("n", "<space>wk", "<C-w><C-k>", "Options - Move focus to upper window")
map("n", "<space>e", ":lua vim.diagnostic.open_float(0, {scope='line'})<CR>", "Options - Show diagnostic message")
map("n", "<C-Up>", "<cmd>resize +2<CR>", "Options - Increase window height")
map("n", "<C-Down>", "<cmd>resize -2<CR>", "Options - Decrease window height")
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", "Options - Decrease window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", "Options - Increase window width")

-- Insert mode keymaps
map("i", "jj", "<Esc>", "Options - Exit insert mode")

-- Terminal mode keymaps
map("t", "<C-\\>", "<C-\\><C-n>", "Options - Exit terminal mode")

-- Visual mode keymaps
map("v", "<", "<gv", "Indent left and reselect")
map("v", ">", ">gv", "Indent right and reselect")

-- Auto-reload files when changed externally (makes autoread work properly)
local autoread_group = vim.api.nvim_create_augroup("AutoRead", { clear = true })

-- Trigger checktime when window focus changes or buffer is entered
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = autoread_group,
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= 'c' then  -- Don't check in command-line mode
      vim.cmd("checktime")
    end
  end,
  desc = "Check if file needs to be reloaded from disk"
})

-- Notification when file is auto-reloaded
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = autoread_group,
  pattern = "*",
  callback = function()
    vim.notify("File reloaded: " .. vim.fn.expand("%"), vim.log.levels.WARN)
  end,
  desc = "Notify when file is auto-reloaded"
})
