-- Python LSP Configuration (basedpyright + ruff)
-- basedpyright: Type checking, completion, and hover
-- ruff: Linting and formatting

local M = {}

-- Basedpyright configuration
M.basedpyright = {
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        -- "basic" catches common errors without being too strict
        -- Options: "off", "basic", "standard", "strict", "all"
        typeCheckingMode = "basic",
        diagnosticMode = "openFilesOnly",
        -- Enable auto import suggestions in completions
        autoImportCompletions = true,
        diagnosticSeverityOverrides = {
          -- Suppress noisy diagnostics that ruff handles better
          reportMissingTypeStubs = false,
          reportPrivateImportUsage = false,
        },
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Disable formatting (handled by ruff)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    -- Keep hover enabled for type information
    -- Keep diagnostics enabled for type checking
  end
}

-- Ruff configuration
M.ruff = {
  init_options = {
    settings = {
      logLevel = "info",
      organizeImports = true,
      fixAll = true,
      lint = {
        enable = true,
        -- "onSave" avoids distracting lint changes while typing
        run = "onSave",
      },
      format = {
        enable = true,
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Disable completion (handled by basedpyright)
    client.server_capabilities.completionProvider = false
    -- Disable hover (handled by basedpyright)
    client.server_capabilities.hoverProvider = false
  end
}

-- Python-specific formatting autocmd
-- Handles organize imports + formatting on save
M.setup_autocmds = function()
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("PythonFormat", { clear = true }),
    pattern = "*.py",
    callback = function(args)
      -- Organize imports first (via ruff)
      local clients = vim.lsp.get_clients({ bufnr = args.buf })
      local encoding = clients[1] and clients[1].offset_encoding or "utf-8"
      local params = vim.lsp.util.make_range_params(nil, encoding)
      params.context = { only = { "source.organizeImports" } }
      local result = vim.lsp.buf_request_sync(args.buf, "textDocument/codeAction", params, 3000)

      if result then
        for _, res in pairs(result) do
          for _, r in pairs(res.result or {}) do
            if r.edit then
              vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
            end
          end
        end
      end

      -- Format the buffer (via ruff)
      vim.lsp.buf.format({ async = false, bufnr = args.buf })
    end,
  })
end

return M
