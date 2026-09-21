local M = {}

M.gopls = {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
        fieldalignment = true,
      },
      -- golangci-lint already runs staticcheck; enabling both duplicates diagnostics
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
