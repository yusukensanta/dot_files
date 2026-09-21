-- aerial.nvim — code outline / symbol tree
-- Opens a sidebar (or floating nav) listing all symbols in the current file.
-- Backends: LSP first, treesitter fallback. Works for all configured LSP languages.
-- Integrates with fzf-lua: require("aerial").fzf_lua() for fuzzy symbol search.
return {
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      backends = { "lsp", "treesitter", "markdown", "man" },
      layout = {
        default_direction = "right",
        min_width = 30,
      },
      attach_mode = "window",
      lsp = { diagnostics_trigger_update = false }, -- Avoid a diagnostics re-trigger per symbol update
      highlight_on_hover = true,
      show_guides = true, -- Statusline symbol display needs lualine's own aerial component configured too
    },
    keys = {
      { "<leader>ao", "<cmd>AerialToggle!<CR>",   desc = "Aerial: toggle outline" },
      { "<leader>af", "<cmd>AerialNavToggle<CR>",  desc = "Aerial: floating nav" },
      -- Navigate symbols — <leader>aj / <leader>ak avoids overriding { } paragraph motions
      { "<leader>aj", "<cmd>AerialNext<CR>",       desc = "Aerial: next symbol" },
      { "<leader>ak", "<cmd>AerialPrev<CR>",       desc = "Aerial: prev symbol" },
    },
  },
}
