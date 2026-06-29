-- Shared LSP utilities
local M = {}

-- Organize imports via LSP codeAction (handles both edit and command responses).
-- Used by python.lua and go.lua setup_autocmds().
function M.organize_imports(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then return end
  local encoding = clients[1].offset_encoding or "utf-8"
  local params = vim.lsp.util.make_range_params(nil, encoding)
  params.context = { only = { "source.organizeImports" } }
  local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 3000)
  if not result then return end
  for client_id, res in pairs(result) do
    local client = vim.lsp.get_client_by_id(client_id)
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit, encoding)
      elseif r.command and client then
        client:exec_cmd(r.command)
      end
    end
  end
end

return M
