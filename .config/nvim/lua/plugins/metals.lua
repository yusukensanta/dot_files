return {
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    ft = { "scala", "sbt", "java" },
    opts = function()
      local buffer_map = require("helpers.keys").buffer_map
      local metals_config = require("metals").bare_config()

      -- Same on_attach function as your other LSP servers
      metals_config.on_attach = function(client, bufnr)
        -- Metals-specific commands
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

      -- Enable LSP completion
      metals_config.capabilities = vim.lsp.protocol.make_client_capabilities()

      -- Debug settings (optional)
      metals_config.init_options.statusBarProvider = "on"

      return metals_config
    end,
    config = function(self, metals_config)
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
