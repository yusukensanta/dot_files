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
    },
  },
}

-- Go-specific formatting autocmd
-- Handles organize imports + formatting on save
M.setup_autocmds = function()
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("GoFormat", { clear = true }),
    pattern = "*.go",
    callback = function(args)
      -- Organize imports first
      local params = vim.lsp.util.make_range_params()
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

      -- Format the buffer
      vim.lsp.buf.format({ async = false, bufnr = args.buf })
    end,
  })
end

return M
