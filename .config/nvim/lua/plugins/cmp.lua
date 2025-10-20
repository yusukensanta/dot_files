-- Autocompletion
return {
  {
    "saghen/blink.cmp",
    dependencies = "rafamadriz/friendly-snippets",
    version = "*",
    opts = {
      keymap = {
        preset = "none",
        ["<C-l>"] = { 'select_prev', 'fallback' },
        ["<C-k>"] = { 'select_next', 'fallback' },
        ["<C-y>"] = { 'select_and_accept', },
        ['<C-e>'] = false,
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono"
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        menu = {
          draw = {
            treesitter = { "lsp" }
          }
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = {
          enabled = true,
        },
      },
      cmdline = {
        keymap = { preset = 'inherit' },
        completion = { menu = { auto_show = true } },
      }
    }
  },
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
        disable_filetype = { "TelescopePrompt", "spectre_panel" },
        disable_in_macro = false,       -- Disable when recording or executing a macro
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
  }
}
