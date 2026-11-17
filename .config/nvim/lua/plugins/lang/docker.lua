-- Dockerfile: dockerfile-language-server (instruction diagnostics,
-- completion, hover).
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { dockerls = {} } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "dockerfile-language-server" } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "dockerfile" } },
  },
}
