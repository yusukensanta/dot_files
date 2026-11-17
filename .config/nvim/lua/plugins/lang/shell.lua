-- Shell (sh/bash): bash-language-server (ShellCheck diagnostics, from
-- Mason's shellcheck), shfmt. Buffer options: after/ftplugin/sh.lua.
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { bashls = {} } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "bash-language-server", "shellcheck", "shfmt" } },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { sh = { "shfmt" }, bash = { "shfmt" } },
      formatters = {
        shfmt = {
          -- shfmt ignores .editorconfig as soon as any style flag is passed,
          -- so a project's .editorconfig decides alone; only without one
          -- are this config's style flags used (indent from the buffer,
          -- -ci: indent switch cases, -bn: binary ops start the next line).
          args = function(_, ctx)
            local args = { "-filename", "$FILENAME" }
            if not vim.fs.find(".editorconfig", { path = ctx.dirname, upward = true })[1] then
              vim.list_extend(args, { "-i", tostring(ctx.shiftwidth), "-ci", "-bn" })
            end
            return args
          end,
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "bash" } },
  },
}
