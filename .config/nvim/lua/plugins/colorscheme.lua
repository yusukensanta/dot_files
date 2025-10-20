return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "moon", -- Your current choice
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
        },
        -- Add these modern features:
        cache = true,
        compile_path = vim.fn.stdpath("cache") .. "/tokyonight",
        on_highlights = function(hl, c)
          -- Custom highlight adjustments
        end,
      })
      vim.cmd.colorscheme("tokyonight-moon")
    end,
  },
}
