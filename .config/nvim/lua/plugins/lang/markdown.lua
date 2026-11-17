-- render-markdown.nvim — inline markdown rendering via extmarks
-- Renders headings, code blocks, tables, checkboxes, callouts in-buffer.
-- No browser, no build step. Replaces iamcco/markdown-preview.nvim.
return {
  {
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
      { "<leader>mp", "<cmd>RenderMarkdown toggle<cr>", desc = "Markdown: toggle rendering" },
    },
  },
}
