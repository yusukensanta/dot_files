return {
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap",
    },
    ft = { "scala", "sbt", "java" },
    opts = function()
      local buffer_map = require("helpers.keys").buffer_map
      local metals_config = require("metals").bare_config()

      metals_config.on_attach = function(client, bufnr)
        -- Wire up Metals DAP adapter
        require("metals").setup_dap()

        buffer_map("n", "<leader>mc", function()
          require("metals").compile_cascade()
        end, "Metals Compile Cascade", bufnr)

        buffer_map("n", "<leader>mt", function()
          require("metals").commands()
        end, "Metals Commands", bufnr)

        buffer_map("n", "<leader>mi", function()
          require("metals").toggle_setting("showImplicitArguments")
        end, "Metals Toggle Implicit Arguments", bufnr)
      end

      metals_config.capabilities = vim.lsp.protocol.make_client_capabilities()
      metals_config.init_options.statusBarProvider = "on"

      return metals_config
    end,
    config = function(self, metals_config)
      local dap = require("dap")

      -- Scala DAP launch configurations
      dap.configurations.scala = {
        {
          type = "scala",
          request = "launch",
          name = "Run File",
          metals = { runType = "run" },
        },
        {
          type = "scala",
          request = "launch",
          name = "Run or Test File",
          metals = { runType = "runOrTestFile" },
        },
        {
          type = "scala",
          request = "launch",
          name = "Test Target",
          metals = { runType = "testTarget" },
        },
      }

      local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = nvim_metals_group,
      })
    end
  }
}
