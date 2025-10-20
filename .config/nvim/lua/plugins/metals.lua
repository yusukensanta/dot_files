return {
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    ft = { "scala", "sbt", "java" },
    opts = function()
      local metals_config = require("metals").bare_config()

      -- Same on_attach function as your other LSP servers
      metals_config.on_attach = function(client, bufnr)
        -- Metals-specific commands
        vim.keymap.set("n", "<leader>mc", function()
          require("metals").compile_cascade()
        end, { buffer = bufnr, desc = "Metals Compile Cascade" })

        vim.keymap.set("n", "<leader>mt", function()
          require("telescope").extensions.metals.commands()
        end, { buffer = bufnr, desc = "Metals Telescope Commands" })

        vim.keymap.set("n", "<leader>mi", function()
          require("metals").toggle_setting("showImplicitArguments")
        end, { buffer = bufnr, desc = "Metals Toggle Implicit Arguments" })
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
