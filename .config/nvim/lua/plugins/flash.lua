-- flash.nvim — instant jump navigation (by folke, same author as tokyonight/lazy/which-key)
-- Press s → type 2-3 chars → jump to any matching position with a single label keystroke.
-- S → treesitter-aware jump (selects whole nodes).
-- Enhances f/F/t/T to show jump labels for multi-occurrence characters.
-- s and S are unused in your config (verified against full keymap inventory).
return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      -- Show jump labels above matches (cleaner than inline)
      label = {
        uppercase = false,
        rainbow = { enabled = false },
      },
      modes = {
        -- Enhance native f/F/t/T with jump labels when there are multiple matches
        char = { enabled = true },
        -- fzf-lua search highlighting integration
        search = { enabled = true },
      },
    },
    keys = {
      -- s: jump to any visible position by typing chars
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash: jump" },
      -- S: jump to treesitter node boundary
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash: treesitter jump" },
      -- r (operator-pending): apply operator to a remote flash target (e.g. yr<char> to yank remote)
      { "r", mode = "o",               function() require("flash").remote() end,             desc = "Flash: remote" },
      -- R (operator-pending/visual): treesitter search across the file
      { "R", mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Flash: treesitter search" },
    },
  },
}
