-- mason.nvim + mason-lspconfig.nvim specs; servers run via vim.lsp.config()/enable() (0.11+).
-- lazy.nvim's directory scan (lazy/core/util.lua M.lsmod) only reads init.lua/*.lua
-- one level deep, so sibling config.lua and servers/ are never treated as plugin
-- specs — they're loaded by the explicit require() calls below.

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
      require("mason-lspconfig").setup({
        -- Rust and Scala are absent on purpose: rustaceanvim and nvim-metals
        -- start their own servers (rust-analyzer from the project's rustup
        -- toolchain, Metals via coursier).
        ensure_installed = {
          "lua_ls",                   -- Lua LSP
          "basedpyright",             -- Python type checking
          "ruff",                     -- Python linting/formatting
          "gopls",                    -- Go LSP (core features)
          "golangci_lint_ls",         -- Go linting (golangci-lint)
          "clangd",                   -- C/C++ LSP
          "ts_ls",                    -- TypeScript/JavaScript type checking
        },
        -- config.lua's setup_servers() enables exactly the servers above.
        -- Left on, mason-lspconfig would also enable any other server
        -- Mason has installed, e.g. a rust_analyzer or metals next to the
        -- one rustaceanvim/nvim-metals already run (two servers per buffer).
        automatic_enable = false,
      })

      local lsp_config = require("plugins.lsp.config")
      lsp_config.setup_lsp_attach()

      -- vim.schedule to ensure proper initialization order
      vim.schedule(function()
        lsp_config.setup_servers()
      end)
    end
  },
}
