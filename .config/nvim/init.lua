-- Load order tested (headless nvim, each file swapped to its opposite
-- extreme, checked for breakage): the only real constraint is
-- config.lazy before config.keymaps — it sets mapleader/maplocalleader,
-- which config.keymaps' <leader>-prefixed maps need already set at
-- registration time (Vim expands <leader> then, not at keypress time).
-- config.options and config.autocmds are independent of everything here
-- and of each other; the current order is just readable, not load-bearing.
vim.loader.enable()
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")

-- Host-local overrides, gitignored and untouched by sync scripts (mirrors
-- zsh's local.d/). pcall so a host without lua/local/init.lua just no-ops.
pcall(require, "local")
