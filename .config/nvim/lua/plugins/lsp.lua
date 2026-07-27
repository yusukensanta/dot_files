-- LSP Plugin Configuration Entry Point
-- Modern Neovim 0.11+ LSP setup using vim.lsp.config() and vim.lsp.enable()

return {
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = {
      "Mason",
      "MasonUpdate",
      "MasonLog",
      "MasonInstall",
      "MasonUninstall",
      "MasonUninstallAll",
    },
    config = function()
      require("mason").setup({
        ui = {
          -- border inherited from 'winborder'
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          }
        }
      })
    end,
    keys = {
      { "<leader>ma", "<cmd>Mason<cr>",        desc = "Mason - Open" },
      { "<leader>lr", "<cmd>lsp restart<cr>",  desc = "LSP: restart server" },
      { "<leader>li", "<cmd>lsp info<cr>",     desc = "LSP: server info" },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      -- Ensure LSP servers are installed via Mason
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",                   -- Lua LSP
          "basedpyright",             -- Python type checking
          "ruff",                     -- Python linting/formatting
          "gopls",                    -- Go LSP (core features)
          "golangci_lint_ls",         -- Go linting (golangci-lint)
          "clangd",                   -- C/C++ LSP
          "ts_ls",                    -- TypeScript/JavaScript type checking
          "rust_analyzer",            -- Rust LSP (fallback if not installed via rustup)
        }
      })

      -- Setup common LSP features (keymaps, formatting, etc.)
      local lsp_config = require("plugins.lsp.config")
      lsp_config.setup_lsp_attach()

      -- Initialize all LSP servers
      -- Wrapped in vim.schedule to ensure proper initialization order
      vim.schedule(function()
        lsp_config.setup_servers()
      end)
    end
  },
}
