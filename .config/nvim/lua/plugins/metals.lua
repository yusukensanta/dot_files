-- nvim-metals - Scala via Metals
--
-- Metals itself is installed by :MetalsInstall / :MetalsUpdate (latest
-- stable, bootstrapped with coursier, which install_libraries.sh installs).
-- Run :MetalsUpdate after a Scala release: an old Metals can't fully
-- support a Scala 3 version newer than itself. Metals runs on $JAVA_HOME,
-- so the project's mise java pin decides the JDK that compiles the code.
return {
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap",
      "saghen/blink.cmp",
    },
    ft = { "scala", "sbt", "java" },
    opts = function()
      local buffer_map = require("helpers.keys").buffer_map
      local metals_config = require("metals").bare_config()

      metals_config.settings = {
        -- Lets <leader>nr/<leader>nf below run tests through Metals.
        testUserInterface = "Test Explorer",
      }

      metals_config.on_attach = function(client, bufnr)
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

        -- Same keys as neotest.lua uses for the other languages. Tests run
        -- through Metals' build server (already compiled, already warm)
        -- and under nvim-dap, so breakpoints work too.
        buffer_map("n", "<leader>nr", function()
          require("metals").select_test_case()
        end, "Test - Pick a test case (Metals)", bufnr)

        buffer_map("n", "<leader>nf", function()
          require("metals").select_test_suite()
        end, "Test - Pick a test suite (Metals)", bufnr)
      end

      -- nvim-metals starts its client with vim.lsp.start(), which doesn't
      -- read vim.lsp.config("*"), so blink.cmp's completion capabilities
      -- have to be passed here explicitly.
      metals_config.capabilities = require("blink.cmp").get_lsp_capabilities()
      metals_config.init_options.statusBarProvider = "on"

      return metals_config
    end,
    -- lazy.nvim calls config(plugin, opts) — "plugin" is the full spec
    -- table (used below for plugin.ft), "metals_config" is this spec's own
    -- opts() return value from above. Previously named "self", which reads
    -- as an OOP method receiver; it isn't one.
    config = function(plugin, metals_config)
      local dap = require("dap")

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
        pattern = plugin.ft,
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = nvim_metals_group,
      })
    end
  }
}
