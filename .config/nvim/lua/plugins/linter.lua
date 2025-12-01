return {
  {
    "mfussenegger/nvim-lint",
    event = {
      "BufReadPost",
      "BufNewFile",
    },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = {},
        javascript = { "biomejs" },
        typescript = { "biomejs" },
        javascriptreact = { "biomejs" },
        typescriptreact = { "biomejs" },
      }
      local lintgroup = vim.api.nvim_create_augroup("lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = lintgroup,
        callback = function()
          lint.try_lint()
        end,
      })
    end
  }
}
