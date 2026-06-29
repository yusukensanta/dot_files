-- nvim-treesitter-context — sticky parent scope at top of window
-- Shows enclosing function/class/struct/block when scrolled past its header.
-- Essential for navigating large files without losing positional context.
return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "BufReadPost",
    opts = {
      max_lines = 3,
      min_window_height = 20,
      multiline_threshold = 1,
      trim_scope = "outer",
      mode = "cursor",
    },
    keys = {
      {
        "<leader>uc",
        function()
          require("treesitter-context").go_to_context(vim.v.count1)
        end,
        desc = "TS Context: jump to parent scope",
      },
      {
        "<leader>ut",
        "<cmd>TSContextToggle<CR>",
        desc = "TS Context: toggle",
      },
    },
  },
}
