local M = {}

M.map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc, noremap = true })
end

M.lsp_map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = true, noremap = true, desc = "LSP - " .. desc })
end

M.buffer_map = function(mode, lhs, rhs, desc, bufnr)
  vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = bufnr or true, noremap = true, desc = desc })
end

M.set_leader = function(key, localkey)
  vim.g.mapleader = key
  vim.g.maplocalleader = localkey or key
  M.map({ "n", "v" }, key, "<nop>")
end

return M
