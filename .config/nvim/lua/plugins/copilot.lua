-- Copilot integration
-- Uses zbirenbaum/copilot.lua (pure Lua) instead of github/copilot.vim (VimScript).
-- Inline suggestions are surfaced via blink.cmp (blink-cmp-copilot source in cmp.lua)
-- rather than as a separate overlay, giving a unified completion UX.
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        -- Disable built-in suggestion/panel overlays — blink.cmp handles display
        suggestion = { enabled = false },
        panel = { enabled = false },
        filetypes = {
          markdown = true,
          help = false,
        },
      })
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
    },
    cmd = "CopilotChat",
    branch = "main",
    build = "make tiktoken",
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        auto_insert_mode = true,
        question_header = "  " .. user .. " ",
        answer_header = "  Copilot ",
        window = {
          layout = "vertical",
          position = "left",
          width = 0.5,
        },
        mappings = {
          complete = {
            insert = "<S-Tab>",
          },
          close = {
            normal = "q",
            insert = "<C-c>",
          },
          submit_prompt = {
            normal = "<CR>",
            insert = "<C-s>",
          },
          show_diff = {
            full_diff = true
          },
        }
      }
    end,
    keys = {
      {
        "<leader>cc",
        function()
          return require("CopilotChat").toggle()
        end,
        desc = "CopilotChat - Toggle",
        mode = { "n", "v" },
      },
      {
        "<leader>cx",
        function()
          return require("CopilotChat").reset()
        end,
        desc = "CopilotChat - Reset",
        mode = { "n", "v" },
      },
      {
        "<leader>cq",
        function()
          vim.ui.input({
            prompt = "Quick Chat: ",
          }, function(input)
            if input ~= "" then
              require("CopilotChat").ask(input)
            end
          end)
        end,
        desc = "CopilotChat - Quick Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>cp",
        function()
          require("CopilotChat").select_prompt()
        end,
        desc = "CopilotChat - Select Prompt",
        mode = { "n", "v" },
      },
      {
        "<leader>cm",
        function()
          require("CopilotChat").select_model()
        end,
        desc = "CopilotChat - Select Model",
        mode = { "n", "v" },
      }
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-chat",
        callback = function()
          vim.opt_local.relativenumber = false
          vim.opt_local.number = false
        end,
      })
      chat.setup(opts)
    end,
  }
}
