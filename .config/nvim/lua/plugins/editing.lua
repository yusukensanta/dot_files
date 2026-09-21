-- Text-editing helpers: auto-pairs, surround, and tag auto-close/rename.
-- blink.cmp itself lives in completion.lua — unrelated to these.
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local npairs = require("nvim-autopairs")

      npairs.setup({
        check_ts = true, -- Enable treesitter integration
        ts_config = {
          lua = { "string", "source" },
          javascript = { "string", "template_string" },
          java = false, -- Don't check treesitter on java
        },
        disable_filetype = { "fzf", "spectre_panel" },
        disable_in_macro = true,        -- Disable when recording or executing a macro
        disable_in_visualblock = false, -- Disable when selecting via visual block mode
        fast_wrap = {
          map = '<M-e>',
          chars = { '{', '[', '(', '"', "'" },
          pattern = [=[[%'%"%)%>%]%)%}%,]]=],
          end_key = '$',
          keys = 'qwertyuiopzxcvbnmasdfghjkl',
          check_comma = true,
          highlight = 'PmenuSel',
          highlight_grey = 'LineNr'
        },
      })
    end,
  },
  {
    "kylechui/nvim-surround",
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      -- Default visual-mode surround key is "S", which collides with
      -- flash.nvim's treesitter-select "S" (flash.lua, modes x/o) — whichever
      -- plugin's vim.keymap.set("x", "S", ...) runs last silently wins in
      -- Visual mode. Moved to "gs" to keep both features working.
      require("nvim-surround").setup({
        keymaps = { visual = "gs" },
      })
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    config = function()
      require('nvim-ts-autotag').setup()
    end,
  },
}
