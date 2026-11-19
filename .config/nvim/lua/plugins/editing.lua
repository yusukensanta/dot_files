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
    version = "^4.0.0",
    event = "VeryLazy",
    -- v4 has no `keymaps` option: plugin/nvim-surround.lua sets the default
    -- keys itself, unless the g: variables below are set first (init runs
    -- before the plugin loads). The default visual-mode key is "S", which
    -- collides with flash.nvim's treesitter-select "S" (flash.lua, modes
    -- x/o) — whichever plugin's vim.keymap.set("x", "S", ...) runs last
    -- silently wins in Visual mode. So the visual keys are set here instead:
    -- "gs" (as before) and "gS" (visual-line, the plugin's own default).
    init = function()
      vim.g.nvim_surround_no_visual_mappings = true
    end,
    config = function()
      vim.keymap.set("x", "gs", "<Plug>(nvim-surround-visual)", { desc = "Surround selection" })
      vim.keymap.set("x", "gS", "<Plug>(nvim-surround-visual-line)", { desc = "Surround selection, on new lines" })
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    -- Only filetypes with tags to close/rename.
    ft = { "html", "xml", "javascriptreact", "typescriptreact", "vue", "svelte", "markdown" },
    config = function()
      require('nvim-ts-autotag').setup()
    end,
  },
}
