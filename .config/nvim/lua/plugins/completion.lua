-- Autocompletion — blink.cmp (not nvim-cmp; despite the ecosystem-standard
-- "cmp" abbreviation, this file was previously named cmp.lua which pointed
-- at the wrong plugin family. Renamed to completion.lua; nvim-autopairs,
-- nvim-surround, and nvim-ts-autotag — unrelated to completion — moved out
-- to editing.lua.)
return {
  {
    "saghen/blink.cmp",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "fang2hou/blink-copilot",
    },
    version = "*",
    opts = {
      keymap = {
        preset = "none",
        ["<C-p>"] = { 'select_prev', 'fallback' },
        ["<C-n>"] = { 'select_next', 'fallback' },
        ["<CR>"] = { 'accept', 'fallback' },
        ["<Tab>"] = { 'snippet_forward', 'fallback' },
        ["<S-Tab>"] = { 'snippet_backward', 'fallback' },
        ["<C-space>"] = { 'show', 'fallback' },
        ['<C-e>'] = { 'hide', 'fallback' },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono"
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
          },
        },
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
}
