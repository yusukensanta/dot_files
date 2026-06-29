-- Go LSP Configuration (gopls + golangci-lint-langserver)
-- gopls: Core LSP features (completion, navigation, refactoring)
-- golangci-lint-langserver: Comprehensive linting via golangci-lint

local M = {}

M.gopls = {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
        fieldalignment = true,
      },
      -- Disable staticcheck in gopls since golangci-lint handles it
      -- This avoids duplicate diagnostics
      staticcheck = false,
      gofumpt = true,
      usePlaceholders = true,
      completeUnimported = true,
      matcher = "Fuzzy",
      experimentalPostfixCompletions = true,
      codelenses = {
        gc_details = true,
        generate = true,
        regenerate_cgo = true,
        run_govulncheck = true,
        test = true,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
      },
    }
  }
}

-- golangci-lint-langserver configuration
-- Provides diagnostics from golangci-lint (includes staticcheck + many more)
M.golangci_lint_ls = {
  cmd = { "golangci-lint-langserver" },
  filetypes = { "go", "gomod" },
  init_options = {
    command = {
      "golangci-lint",
      "run",
      "--output.json.path=stdout",
      "--show-stats=false",
      "--timeout=60s",
    },
  },
}

-- Go-specific formatting autocmd
-- Handles organize imports + formatting on save
M.setup_autocmds = function()
  local lsp_helpers = require("helpers.lsp")
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("GoFormat", { clear = true }),
    pattern = "*.go",
    callback = function(args)
      lsp_helpers.organize_imports(args.buf)
      vim.lsp.buf.format({ async = false, bufnr = args.buf })
    end,
  })
end

return M
