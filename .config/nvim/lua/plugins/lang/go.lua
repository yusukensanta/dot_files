-- Go: gopls + golangci-lint, goimports/gofumpt, delve, go test. Buffer
-- options: after/ftplugin/go.lua (and gomod/gosum); the gotmpl filetype is
-- detected in ftdetect/gotmpl.lua.
--
-- On save, conform runs goimports (adds/removes imports) then gofumpt, the
-- same formatting gopls applies with `gofumpt = true` below.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
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
            },
          },
        },
        golangci_lint_ls = {
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
        },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = { "gopls", "golangci-lint-langserver", "goimports", "gofumpt", "delve" },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { go = { "goimports", "gofumpt" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "go", "gomod", "gosum", "gowork", "gotmpl" } },
  },
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup()
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "nvim-neotest/neotest-go" },
    opts = {
      adapters = {
        ["neotest-go"] = { experimental = { test_table = true } },
      },
    },
  },
}
