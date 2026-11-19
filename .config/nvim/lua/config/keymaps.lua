-- Global keymaps not owned by a specific plugin (each plugin file registers
-- its own bindings via keys=/map() instead — see doc/KEYMAP.md for the full
-- picture). Must load after config.lazy (init.lua), which sets mapleader —
-- the <leader>-prefixed maps below need that already set.
--
-- Neovim's own defaults are kept wherever possible: tab pages use gt/gT and
-- :tabnew, buffers ]b/[b (barbar's order, lualine.lua), tags <C-]>/<C-t>
-- and ]t/[t, the diagnostic float <C-w>d.

local map = require("helpers.keys").map

-- Neovim 0.12 built-in plugins (packadd here, next to the keymaps below
-- that depend on them: :Undotree and :DiffTool don't exist until this runs)
vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")

-- Normal mode keymaps
-- Direct single-chord window nav.
-- <C-l> replaces the default <C-l> (clear search highlight + redraw), so
-- <Esc> below clears the highlight instead.
map("n", "<C-h>", "<C-w><C-h>", "Keymaps - Move focus to left window")
map("n", "<C-l>", "<C-w><C-l>", "Keymaps - Move focus to right window")
map("n", "<C-j>", "<C-w><C-j>", "Keymaps - Move focus to lower window")
map("n", "<C-k>", "<C-w><C-k>", "Keymaps - Move focus to upper window")
map("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", "Keymaps - Clear search highlight")
map("n", "<leader>e", function()
  vim.diagnostic.open_float({ scope = "line" })
end, "Keymaps - Show diagnostic message")
map("n", "<C-Up>", "<cmd>resize +2<CR>", "Keymaps - Increase window height")
map("n", "<C-Down>", "<cmd>resize -2<CR>", "Keymaps - Decrease window height")
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", "Keymaps - Decrease window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", "Keymaps - Increase window width")

-- Insert mode keymaps
map("i", "jj", "<Esc>", "Keymaps - Exit insert mode")

-- Terminal mode keymaps
map("t", "<C-\\>", "<C-\\><C-n>", "Keymaps - Exit terminal mode")

-- Visual mode keymaps. "x", not "v": "v" also covers Select mode, where a
-- snippet placeholder must take a typed "<" or ">" as text.
map("x", "<", "<gv", "Indent left and reselect")
map("x", ">", ">gv", "Indent right and reselect")

-- Built-in tools (0.12+)
map("n", "<leader>uu", "<cmd>Undotree<CR>", "Undotree - Toggle undo history")
map("n", "<leader>ud", "<cmd>DiffTool<CR>", "DiffTool - Compare directories")
