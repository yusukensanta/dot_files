local M = {}

M.map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- bufnr optional, defaulting to the current buffer — but LspAttach fires
-- for whatever buffer just finished attaching, which is not guaranteed to
-- be the current one (background attach, :bufdo, previews, ...), so
-- callers driven by an LspAttach autocmd should always pass args.buf
-- explicitly rather than rely on the default.
M.lsp_map = function(mode, lhs, rhs, desc, bufnr)
  vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = bufnr or true, desc = "LSP - " .. desc })
end

M.buffer_map = function(mode, lhs, rhs, desc, bufnr)
  vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = bufnr or true, desc = desc })
end

M.set_leader = function(key, localkey)
  vim.g.mapleader = key
  vim.g.maplocalleader = localkey or key
  -- "x", not "v": Select mode (snippet placeholders) must take the key as text.
  M.map({ "n", "x" }, key, "<nop>")
end

return M
