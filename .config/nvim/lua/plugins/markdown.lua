return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
    config = function()
      local map = require("helpers.keys").map

      map("n",
        "<leader>mp",
        ":MarkdownPreviewToggle<CR>",
        "Markdown Preview - Toggle"
      )
    end,
  }
}
