local M = {}

M.map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc, noremap = true })
end

-- bufnr optional, defaulting to the current buffer — but LspAttach fires
-- for whatever buffer just finished attaching, which is not guaranteed to
-- be the current one (background attach, :bufdo, previews, ...), so
-- callers driven by an LspAttach autocmd should always pass args.buf
-- explicitly rather than rely on the default.
M.lsp_map = function(mode, lhs, rhs, desc, bufnr)
  vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = bufnr or true, noremap = true, desc = "LSP - " .. desc })
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
