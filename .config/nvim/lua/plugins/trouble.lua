-- trouble.nvim v3 — structured LSP result panel (by folke)
-- Instead of raw quickfix for gr / gd results, opens a navigable panel with
-- icons, grouping by file, and jump-to-line. Essential for tracing call graphs
-- and reference chains across large codebases.
-- All <leader>x* keys are free in your config (verified).
return {
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    opts = {
      modes = {
        -- Show workspace diagnostics with error count in the title
        diagnostics = {
          auto_close = false,
          auto_preview = true,
        },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",          desc = "Trouble: workspace diagnostics" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Trouble: buffer diagnostics" },
      { "<leader>xd", "<cmd>Trouble lsp_definitions toggle<cr>",      desc = "Trouble: LSP definitions" },
      { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>",       desc = "Trouble: LSP references" },
      { "<leader>xs", "<cmd>Trouble lsp_document_symbols toggle<cr>", desc = "Trouble: document symbols" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",               desc = "Trouble: quickfix list" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>",              desc = "Trouble: location list" },
    },
  },
}
