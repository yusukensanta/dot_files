-- vim-illuminate — auto-highlight all visible occurrences of symbol under cursor
-- Uses LSP references when available, falls back to treesitter, then regex.
-- Helps track variable usage across a file without searching.
return {
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 200,
        under_cursor = true,
        min_count_to_highlight = 2,
        filetypes_denylist = {
          "oil",
          "Trouble",
          "trouble",
          "aerial",
          "lazy",
          "mason",
          "help",
          "fzf",
          "DiffviewFiles",
        },
        large_file_cutoff = 5000,
      })

      local map = require("helpers.keys").map
      map("n", "]]", function() require("illuminate").goto_next_reference(false) end, "Illuminate: next reference")
      map("n", "[[", function() require("illuminate").goto_prev_reference(false) end, "Illuminate: prev reference")
    end,
  },
}
