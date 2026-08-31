vim.loader.enable()
require("config.options")
require("config.lazy")
require("config.format")

-- Host-local overrides, gitignored and untouched by sync scripts (mirrors
-- zsh's local.d/). pcall so a host without lua/local/init.lua just no-ops.
pcall(require, "local")
