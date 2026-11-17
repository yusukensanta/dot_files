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
      -- Navigation uses the plugin's default keymaps: <M-n>/<M-p> next/prev
      -- reference, <M-i> reference text object. Not ]]/[[: the ftplugins of
      -- Python, Go, Rust, Java and Markdown map those buffer-locally, which
      -- wins over a global map.
    end,
  },
}
