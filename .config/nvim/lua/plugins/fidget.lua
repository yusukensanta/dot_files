-- fidget.nvim — LSP progress spinner (bottom-right floating, disappears when done)
-- Covers rust-analyzer indexing, gopls analysis, metals BSP compile, etc.
-- override_vim_notify = false: snacks.nvim owns vim.notify; fidget handles LSP progress only.
return {
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      progress = {
        display = {
          render_limit = 8,
          done_ttl = 2,
        },
      },
      notification = {
        override_vim_notify = false,
        window = { winblend = 0 },
      },
    },
  },
}
