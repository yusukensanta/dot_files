-- Buffer-local settings shared by the after/ftplugin/ files.
local M = {}

-- indent(width, expandtab): one indent level is `width` columns; a tab is
-- shown as `width` columns too. expandtab defaults to true.
function M.indent(width, expandtab)
  vim.opt_local.shiftwidth = width
  vim.opt_local.tabstop = width
  vim.opt_local.expandtab = expandtab ~= false
end

-- Prose: spell checking and soft-wrapping at word boundaries.
function M.prose()
  vim.opt_local.spell = true
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
end

return M
