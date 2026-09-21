local M = {}

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
  end
}

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

M.setup_autocmds = function()
  local lsp_helpers = require("helpers.lsp")
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("PythonFormat", { clear = true }),
    pattern = "*.py",
    callback = function(args)
      lsp_helpers.organize_imports(args.buf)
      vim.lsp.buf.format({ async = false, bufnr = args.buf })
    end,
  })
end

return M
