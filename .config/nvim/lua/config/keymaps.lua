-- Global keymaps not owned by a specific plugin (each plugin file registers
-- its own bindings via keys=/map() instead — see doc/KEYMAP.md for the full
-- picture). Split out of options.lua, which used to mix vim.opt settings,
-- these bindings, and unrelated autocmds in one file despite its name.
-- Loaded after config.options in init.lua.

local map = require("helpers.keys").map

-- Neovim 0.12 built-in plugins (packadd here, next to the keymaps below
-- that depend on them: :Undotree and :DiffTool don't exist until this runs)
vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")

-- Normal mode keymaps
map("n", "<C-p>", ":tabprev<CR>", "Keymaps - Tab previous")
map("n", "<C-n>", ":tabnext<CR>", "Keymaps - Tab next")
map("n", "<C-t>", ":tabnew<CR>", "Keymaps - Tab new")
-- Buffer navigation handled by barbar.nvim (lualine.lua)
-- Direct single-chord window nav (primary); <space>w* kept as fallback.
map("n", "<C-h>", "<C-w><C-h>", "Keymaps - Move focus to left window")
map("n", "<C-l>", "<C-w><C-l>", "Keymaps - Move focus to right window")
map("n", "<C-j>", "<C-w><C-j>", "Keymaps - Move focus to lower window")
map("n", "<C-k>", "<C-w><C-k>", "Keymaps - Move focus to upper window")
map("n", "<space>wh", "<C-w><C-h>", "Keymaps - Move focus to left window")
map("n", "<space>wl", "<C-w><C-l>", "Keymaps - Move focus to right window")
map("n", "<space>wj", "<C-w><C-j>", "Keymaps - Move focus to lower window")
map("n", "<space>wk", "<C-w><C-k>", "Keymaps - Move focus to upper window")
map("n", "<space>e", ":lua vim.diagnostic.open_float(0, {scope='line'})<CR>", "Keymaps - Show diagnostic message")
map("n", "<C-Up>", "<cmd>resize +2<CR>", "Keymaps - Increase window height")
map("n", "<C-Down>", "<cmd>resize -2<CR>", "Keymaps - Decrease window height")
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", "Keymaps - Decrease window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", "Keymaps - Increase window width")

-- Insert mode keymaps
map("i", "jj", "<Esc>", "Keymaps - Exit insert mode")

-- Terminal mode keymaps
map("t", "<C-\\>", "<C-\\><C-n>", "Keymaps - Exit terminal mode")

-- Visual mode keymaps
map("v", "<", "<gv", "Indent left and reselect")
map("v", ">", ">gv", "Indent right and reselect")

-- Built-in tools (0.12+)
map("n", "<leader>uu", "<cmd>Undotree<CR>", "Undotree - Toggle undo history")
map("n", "<leader>ud", "<cmd>DiffTool<CR>", "DiffTool - Compare directories")
