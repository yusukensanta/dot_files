-- TOML: Taplo, as language server (syntax and schema diagnostics) and as
-- formatter (follows the project's .taplo.toml / taplo.toml).
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { taplo = {} } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "taplo" } },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { toml = { "taplo" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml" } },
  },
}
