-- Debugging core, shared by every language: nvim-dap, its UI and keymaps.
-- It names no language itself — each lua/plugins/lang/<language>.lua brings
-- its own adapter (nvim-dap-python, nvim-dap-go, rustaceanvim, nvim-metals)
-- and loads it only for that language's files; their debug adapters are
-- installed through mason-tool-installer (see lsp.lua).
local function dap(fn, ...)
  local args = { ... }
  return function()
    require("dap")[fn](unpack(args))
  end
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dapui = require("dapui")
      dapui.setup()

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
          if options.virt_text_pos == "inline" then
            return " = " .. variable.value
          else
            return variable.name .. " = " .. variable.value
          end
        end,
        virt_text_pos = "inline",
      })

      local listeners = require("dap").listeners
      listeners.after.event_initialized["dapui_config"] = dapui.open
      listeners.before.event_terminated["dapui_config"] = dapui.close
      listeners.before.event_exited["dapui_config"] = dapui.close
    end,
    keys = {
      { "<leader>db", dap("toggle_breakpoint"), desc = "DAP - Toggle Breakpoint" },
      { "<leader>dc", dap("continue"), desc = "DAP - Continue" },
      { "<leader>dv", dap("step_over"), desc = "DAP - Step Over" },
      { "<leader>di", dap("step_into"), desc = "DAP - Step Into" },
      { "<leader>do", dap("step_out"), desc = "DAP - Step Out" },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "DAP - Open REPL",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "DAP - Toggle UI",
      },
      { "<leader>dt", dap("terminate"), desc = "DAP - Terminate" },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end,
        desc = "DAP - Conditional Breakpoint",
      },
    },
  },
}
