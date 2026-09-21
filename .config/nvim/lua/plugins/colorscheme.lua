return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "moon",
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
        },
        cache = true,
        compile_path = vim.fn.stdpath("cache") .. "/tokyonight",
      })
      vim.cmd.colorscheme("tokyonight-moon")
    end,
  },
}
