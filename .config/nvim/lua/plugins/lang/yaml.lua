-- YAML: yaml-language-server (syntax and, for files it recognises, schema
-- validation from SchemaStore), Prettier.
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { yamlls = {} } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "yaml-language-server", "prettier" } },
  },
  {
    "stevearc/conform.nvim",
    -- Prettier follows the project's .prettierrc when there is one.
    opts = { formatters_by_ft = { yaml = { "prettier" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
}
