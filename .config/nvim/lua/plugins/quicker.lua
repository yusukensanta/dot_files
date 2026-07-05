-- quicker.nvim — enhanced quickfix (syntax highlighting, context lines, editable)
-- stevearc (same author as conform.nvim + oil.nvim).
-- Editable QF: modify text in quickfix buffer → writes back to source files.
-- > / < expand or collapse context lines around each result.
return {
  {
    "stevearc/quicker.nvim",
    event = "FileType qf",
    opts = {
      keys = {
        {
          ">",
          function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end,
          desc = "Quicker: expand context",
        },
        {
          "<",
          function() require("quicker").collapse() end,
          desc = "Quicker: collapse context",
        },
      },
    },
  },
}
