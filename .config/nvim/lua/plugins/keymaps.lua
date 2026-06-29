return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({
        preset = "modern",
        delay = 200,
      })
      wk.add({
        { "<leader>b",  group = "Buffer" },
        { "<leader>c",  group = "Copilot / Code" },
        { "<leader>d",  group = "DAP" },
        { "<leader>g",  group = "Git" },
        { "<leader>gc", group = "Git Conflict / Commit" },
        { "<leader>h",  group = "Gitsigns Hunks" },
        { "<leader>l",  group = "Lazy" },
        { "<leader>ma", group = "Mason" },
        { "<leader>n",  group = "Neotest" },
        { "<leader>r",  group = "Rename / Rust" },
        { "<leader>t",  group = "Fuzzy Find" },
        { "<leader>u",  group = "Undotree / Utils" },
        { "<leader>w",  group = "Workspace / Windows" },
        { "<leader>x",  group = "Trouble" },
        { "<leader>a",  group = "Aerial" },
        { "<space>c",   group = "Code Action" },
      })
    end,
  }
}
