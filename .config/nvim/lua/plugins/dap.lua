return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "jay-babu/mason-nvim-dap.nvim",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Auto-install DAP adapters via Mason
      require("mason-nvim-dap").setup({
        ensure_installed = { "debugpy", "delve" },
        automatic_installation = true,
      })

      -- Setup DAP UI
      dapui.setup()

      -- Setup virtual text
      require("nvim-dap-virtual-text").setup({
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_as_changed = false,
        show_stop_reason = true,
        commented = false,
        only_first_definition = true,
        all_references = false,
        clear_on_continue = false,
        display_callback = function(variable, buf, stackframe, node, options)
          if options.virt_text_pos == 'inline' then
            return ' = ' .. variable.value
          else
            return variable.name .. ' = ' .. variable.value
          end
        end,
        virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',
      })

      -- Python DAP (uses Mason-managed debugpy)
      require("dap-python").setup(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python")

      -- Go DAP (uses Mason-managed delve)
      require("dap-go").setup()

      -- Auto open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- Keymappings
      local map = require("helpers.keys").map
      map("n", "<leader>db", dap.toggle_breakpoint, "DAP - Toggle Breakpoint")
      map("n", "<leader>dc", dap.continue, "DAP - Continue")
      map("n", "<leader>ds", dap.step_over, "DAP - Step Over")
      map("n", "<leader>di", dap.step_into, "DAP - Step Into")
      map("n", "<leader>do", dap.step_out, "DAP - Step Out")
      map("n", "<leader>dr", dap.repl.open, "DAP - Open REPL")
      map("n", "<leader>du", dapui.toggle, "DAP - Toggle UI")
      map("n", "<leader>dt", dap.terminate, "DAP - Terminate")
      map("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
      end, "DAP - Conditional Breakpoint")
    end,
  }
}
