-- indent-blankline.nvim v3 (ibl) — indent guides + scope highlighting
-- Renders thin vertical lines at each indent level and highlights current scope.
-- Helps parse deeply nested code at a glance.
return {
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "BufReadPost",
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = {
        enabled = true,
        show_start = true,
        show_end = false,
      },
      exclude = {
        filetypes = {
          "help",
          "lazy",
          "mason",
          "oil",
          "Trouble",
          "trouble",
          "aerial",
          "dashboard",
          "neo-tree",
          "notify",
        },
      },
    },
  },
}
