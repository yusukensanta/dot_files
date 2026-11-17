-- Python (tooling: lua/plugins/lang/python.lua).
require("helpers.buffer").indent(4)
-- Ruff's default line length.
vim.opt_local.colorcolumn = "88"
-- Prefix virtual-text diagnostics with what reported them (see the
-- vim.diagnostic.config() call in lua/config/options.lua).
vim.b.diagnostic_source_tags = { Ruff = "[LINT] ", basedpyright = "[COMP] " }
