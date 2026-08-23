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
        { "<leader>gc", group = "Git Commit" },
        -- No group entry for <leader>l, <leader>ma, <leader>gx: each of
        -- those keys is ALSO bound directly (lazy.show, :Mason,
        -- :GitConflictListQf respectively), not just a prefix for the
        -- longer bindings under it (<leader>lf/lr/li,
        -- <leader>gxo/t/b/n) — labeling it a "group" implied it only
        -- led to sub-choices, which isn't true. which-key still shows
        -- those sub-mappings when the prefix is held, just without a
        -- misleading top-level category name.
        { "<leader>h",  group = "Gitsigns Hunks" },
        { "<leader>n",  group = "Neotest" },
        { "<leader>r",  group = "Rename / Rust" },
        { "<leader>t",  group = "Fuzzy Find" },
        { "<leader>u",  group = "Undotree / Utils" },
        { "<leader>w",  group = "Workspace / Windows" },
        { "<leader>x",  group = "Trouble" },
        { "<leader>a",  group = "Aerial" },
        { "<leader>s",  group = "Snacks / Dropbar" },
        { "<space>c",   group = "Code Action" },
      })
    end,
  }
}
