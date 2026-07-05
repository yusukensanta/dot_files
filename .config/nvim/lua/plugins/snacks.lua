-- snacks.nvim — bigfile protection + styled vim.notify (folke)
-- bigfile: disables treesitter/LSP/illuminate above 1.5 MB to prevent freezes.
-- notifier: replaces bare echoarea vim.notify with floating toasts.
-- All other snack components explicitly disabled — existing plugins cover their roles.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true, size = 1.5 * 1024 * 1024 },
      notifier = { enabled = true, timeout = 3000 },
    },
    keys = {
      { "<leader>sn", function() Snacks.notifier.show_history() end, desc = "Snacks: notification history" },
      { "<leader>sd", function() Snacks.notifier.hide() end,         desc = "Snacks: dismiss notifications" },
    },
  },
}
