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
      -- Don't re-trigger diagnostics on symbol update (performance)
      lsp = { diagnostics_trigger_update = false },
      -- Show a preview of the symbol when navigating
      highlight_on_hover = true,
      -- Update the statusline with the current symbol (requires lualine config)
      show_guides = true,
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
