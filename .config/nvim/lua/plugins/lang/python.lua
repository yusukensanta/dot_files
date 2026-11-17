-- Python: basedpyright (types, completion) + Ruff (lint, import order,
-- format), debugpy, pytest. Buffer options: after/ftplugin/python.lua.
--
-- On save, conform runs Ruff's CLI: organize imports, then format. Both read
-- the project's pyproject.toml / ruff.toml, so the result matches
-- `ruff check --select I --fix && ruff format` run in the project.
local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
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
                  -- Suppress noisy diagnostics that Ruff handles better
                  reportMissingTypeStubs = false,
                  reportPrivateImportUsage = false,
                },
              },
            },
          },
          on_attach = function(client)
            -- Formatting is Ruff's (through conform)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
        ruff = {
          init_options = {
            settings = {
              logLevel = "info",
              organizeImports = true,
              fixAll = true,
              lint = { enable = true },
              format = { enable = true },
            },
          },
          on_attach = function(client)
            -- Hover is basedpyright's
            client.server_capabilities.hoverProvider = false
          end,
        },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "basedpyright", "ruff", "debugpy" } },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { python = { "ruff_organize_imports", "ruff_format" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "python" } },
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-python").setup(mason_path .. "/debugpy/venv/bin/python")
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "nvim-neotest/neotest-python" },
    opts = {
      adapters = {
        ["neotest-python"] = {
          dap = { justMyCode = false },
          runner = "pytest",
        },
      },
    },
  },
}
