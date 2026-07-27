-- dropbar.nvim — winbar breadcrumb navigation (LSP + treesitter backends)
-- Shows MyStruct > my_method > inner_block at top of each window.
-- Clickable: opens a drop-down picker to jump to any ancestor symbol.
-- Complements aerial (aerial = file overview, dropbar = passive orientation).
return {
  {
    "Bekaboo/dropbar.nvim",
    event = "BufReadPost",
    opts = {
      bar = {
        attach_events = { "BufReadPost", "BufNewFile" },
      },
    },
    keys = {
      {
        "<leader>sb",
        function() require("dropbar.api").pick() end,
        desc = "Dropbar: pick symbol in winbar",
      },
    },
  },
}
