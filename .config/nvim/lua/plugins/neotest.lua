return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "stevanmilic/neotest-scala",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-scala")({
            -- Uses metals BSP to run tests; no extra config needed for standard sbt projects
          }),
          require("neotest-python")({
            dap = { justMyCode = false },
            runner = "pytest",
          }),
          require("neotest-go")({
            experimental = { test_table = true },
          }),
        },
        output = { open_on_run = true },
        summary = { animated = true },
      })

      local map = require("helpers.keys").map
      map("n", "<leader>nr", function() require("neotest").run.run() end, "Test - Run nearest")
      map("n", "<leader>nf", function() require("neotest").run.run(vim.fn.expand("%")) end, "Test - Run file")
      map("n", "<leader>ns", function() require("neotest").summary.toggle() end, "Test - Toggle summary")
      map("n", "<leader>no", function() require("neotest").output.open({ enter = true }) end, "Test - Open output")
      map("n", "<leader>nd", function() require("neotest").run.run({ strategy = "dap" }) end, "Test - Debug nearest")
      map("n", "[t", function() require("neotest").jump.prev({ status = "failed" }) end, "Test - Jump prev failed")
      map("n", "]t", function() require("neotest").jump.next({ status = "failed" }) end, "Test - Jump next failed")
    end,
  },
}
