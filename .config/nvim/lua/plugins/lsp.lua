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
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          }
        }
      })
    end,
    keys = {
      { "<leader>ma", "<cmd>Mason<cr>", desc = "Mason - Open" },
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
          "lua_ls",
          "basedpyright",
          "ruff",
          "gopls",
          "clangd",
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
