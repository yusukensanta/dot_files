-- snacks.nvim — bigfile protection + styled vim.notify + indent guides (folke)
-- bigfile: disables treesitter/LSP/illuminate above 1.5 MB to prevent freezes.
-- notifier: replaces bare echoarea vim.notify with floating toasts.
-- indent: replaces lukas-reineke/indent-blankline.nvim — snacks core is already
-- loaded eagerly (lazy=false) for bigfile/notifier, so enabling its indent
-- module is zero marginal plugin load vs running ibl as a second plugin doing
-- the same job. Default filter() already excludes any buftype ~= "" (help,
-- oil, Trouble, aerial, Mason, Lazy, notify float, etc all use non-"" buftype),
-- matching ibl's old filetype exclude list without needing one here.
-- All other snack components explicitly disabled — existing plugins cover their roles.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true, size = 1.5 * 1024 * 1024 },
      notifier = { enabled = true, timeout = 3000 },
      indent = {
        enabled = true,
        indent = { char = "│" },
        scope = { enabled = true, underline = true },
      },
    },
    keys = {
      { "<leader>sn", function() Snacks.notifier.show_history() end, desc = "Snacks: notification history" },
      { "<leader>sd", function() Snacks.notifier.hide() end,         desc = "Snacks: dismiss notifications" },
    },
  },
}
