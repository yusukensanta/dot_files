-- flash.nvim — instant jump navigation (by folke, same author as tokyonight/lazy/which-key)
-- Press s → type 2-3 chars → jump to any matching position with a single label keystroke.
-- S → treesitter-aware jump (selects whole nodes).
-- Enhances f/F/t/T to show jump labels for multi-occurrence characters.
-- s is unused elsewhere. S collided with nvim-surround's default visual-mode
-- surround key (also "S") — nvim-surround's is remapped to "gs" (see
-- editing.lua) so both keep working.
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
        -- char mode disabled: it hooks ; and , (repeat f/F/t/T), causing unexpected
        -- dimming of non-target characters after a character motion
        char = { enabled = false },
        search = { enabled = true },
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash: jump" },
      -- x/o only, not n: in normal mode this would leave an unexpected visual selection
      { "S", mode = { "x", "o" }, function() require("flash").treesitter() end, desc = "Flash: treesitter select" },
      { "r", mode = "o",               function() require("flash").remote() end,             desc = "Flash: remote" },
      { "R", mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Flash: treesitter search" },
    },
  },
}
