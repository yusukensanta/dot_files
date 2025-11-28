-- Python LSP Configuration (basedpyright + ruff)
-- basedpyright: Type checking and completion
-- ruff: Linting and formatting

local M = {}

-- Basedpyright configuration
M.basedpyright = {
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        typeCheckingMode = "off",
        diagnosticMode = "openFilesOnly",
        autoImportCompletions = false,
        diagnosticSeverityOverrides = {
          reportMissingTypeStubs = false,
          reportOptionalCall = false,
          reportOptionalIterable = false,
          reportOptionalMemberAccess = false,
          reportOptionalOperand = false,
          reportOptionalSubscript = false,
          reportPrivateImportUsage = false,
          reportUnboundVariable = false,
        },
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Disable diagnostics (handled by ruff)
    client.server_capabilities.diagnosticProvider = false
    -- Disable formatting (handled by ruff)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    -- Disable hover (can be enabled if preferred)
    client.server_capabilities.hoverProvider = false
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

return M
