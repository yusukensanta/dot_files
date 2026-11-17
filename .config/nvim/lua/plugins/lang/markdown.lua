-- Markdown: in-buffer rendering (render-markdown.nvim), Prettier. Buffer
-- options: after/ftplugin/markdown.lua.
return {
  {
    -- Renders headings, code blocks, tables, checkboxes, callouts in-buffer
    -- via extmarks. No browser, no build step.
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    opts = {
      render_modes = true,
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        width = "block",
      },
      checkbox = {
        enabled = true,
      },
      bullet = {
        enabled = true,
      },
    },
    keys = {
      { "<leader>mp", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Markdown: toggle rendering" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "prettier" } },
  },
  {
    "stevearc/conform.nvim",
    -- Prettier follows the project's .prettierrc when there is one.
    opts = { formatters_by_ft = { markdown = { "prettier" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
}
