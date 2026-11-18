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
      -- ]u/[u (u for "usage") jump to the next/prev reference, the same
      -- ]x/[x shape as ]d, ]c and ]n. Not ]]/[[: the ftplugins of Python,
      -- Go, Rust, Java and Markdown map those buffer-locally, which wins over
      -- a global map. Not ]r/[r: Neovim's own spelling motion (rare words).
      -- The plugin's defaults stay too: <M-n>/<M-p>, and <M-i> as a
      -- reference text object.
      local illuminate = require("illuminate")
      vim.keymap.set("n", "]u", illuminate.goto_next_reference, { desc = "Next reference" })
      vim.keymap.set("n", "[u", illuminate.goto_prev_reference, { desc = "Prev reference" })
    end,
  },
}
