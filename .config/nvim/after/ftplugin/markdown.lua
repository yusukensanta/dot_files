-- Markdown (tooling: lua/plugins/lang/markdown.lua). Neovim's own
-- markdown ftplugin sets a 4-column indent; lists here use 2.
require("helpers.buffer").indent(2)
require("helpers.buffer").prose()
