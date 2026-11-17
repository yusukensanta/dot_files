-- Lua: lua_ls (+ lazydev for Neovim's API and the installed plugins),
-- stylua. Formatting follows the nearest stylua.toml (this config has one).
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
      },
    },
  },
  {
    -- Adds Neovim's runtime and only the plugins a file actually requires to
    -- lua_ls's library, instead of every runtime path up front.
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "lua-language-server", "stylua" } },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { lua = { "stylua" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "lua", "luadoc" } },
  },
}
