-- Formatting core, shared by every language: conform.nvim is the only thing
-- that formats on save. It names no language itself — each
-- lua/plugins/lang/<language>.lua adds its `formatters_by_ft` (and any
-- formatter overrides) here, and conform only runs a formatter for a buffer
-- whose filetype lists it. A filetype with no formatter listed falls back to
-- its language server's formatting, if it has one (clangd, Metals).
--
-- Per buffer, set from after/ftplugin/<filetype>.lua:
--   vim.b.format_timeout_ms   how long a save waits for the formatter (500)
--   vim.b.disable_autoformat  skip format-on-save
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      notify_on_error = true,
      formatters_by_ft = {},
      formatters = {},
      format_on_save = function(bufnr)
        if vim.b[bufnr].disable_autoformat then
          return nil
        end
        return {
          timeout_ms = vim.b[bufnr].format_timeout_ms or 500,
          lsp_format = "fallback",
        }
      end,
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
  },
}
