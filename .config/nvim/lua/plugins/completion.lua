-- Autocompletion — blink.cmp, not nvim-cmp: named completion.lua rather
-- than the ecosystem-standard "cmp.lua" so it doesn't imply the wrong
-- plugin family. nvim-autopairs, nvim-surround, and nvim-ts-autotag —
-- unrelated to completion — live in editing.lua instead.
return {
  {
    "saghen/blink.cmp",
    dependencies = { "rafamadriz/friendly-snippets" },
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
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
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
      -- cmdline: blink's own defaults (its "cmdline" keymap preset, menu on
      -- <Tab>). Inheriting the keymap above would put "accept" on <CR>, so
      -- Enter could accept a menu item instead of running the command.
    }
  },
}
