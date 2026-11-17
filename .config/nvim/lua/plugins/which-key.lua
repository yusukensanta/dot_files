-- which-key.nvim group labels only — actual keymap definitions live in
-- config/keymaps.lua and each plugin's own file (see doc/KEYMAP.md).
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
        -- Every group below is a pure prefix: no key here is also a mapping
        -- of its own (that would fire only after 'timeoutlen').
        { "<leader>b",  group = "Buffer" },
        { "<leader>c",  group = "Copilot / Code" },
        { "<leader>d",  group = "DAP" },
        { "<leader>g",  group = "Git" },
        { "<leader>gb", group = "Git Branch / Blame" },
        { "<leader>gc", group = "Git Commit" },
        { "<leader>go", group = "Octo (GitHub)" },
        { "<leader>gx", group = "Git Conflict" },
        { "<leader>h",  group = "Gitsigns Hunks" },
        { "<leader>l",  group = "LSP" },
        { "<leader>m",  group = "Mason / Metals / Markdown" },
        { "<leader>n",  group = "Neotest" },
        { "<leader>r",  group = "Rename / Rust" },
        { "<leader>t",  group = "Fuzzy Find" },
        { "<leader>u",  group = "Utils / Toggles" },
        { "<leader>w",  group = "LSP Workspace" },
        { "<leader>x",  group = "Trouble" },
        { "<leader>a",  group = "Aerial" },
        { "<leader>s",  group = "Snacks / Dropbar" },
        { "<space>c",   group = "Code Action" },
        { "<space>w",   group = "Windows" },
      })
    end,
  }
}
