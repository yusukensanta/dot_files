-- marks.nvim — enhanced marks with gutter signs
-- Renders mark letters in the sign column so you can see all bookmarks at a glance.
-- Uses standard Vim mark keybindings so muscle memory is preserved:
--   m<letter>  — set mark
--   '<letter>  — jump to mark
--   dm<letter> — delete mark
--   m,         — set next available mark automatically
--   m;         — toggle the next mark at the cursor
-- Gutter indicators complement gitsigns.nvim (both use the sign column).
return {
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      default_mappings = true,
      -- Show marks in the sign column
      signs = true,
      -- Exclude line/column marks from display (keep it clean)
      excluded_filetypes = { "NvimTree", "aerial", "Trouble", "oil" },
    },
  },
}
