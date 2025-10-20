return {
  {
    "github/copilot.vim",
    branch = "release",
    keys = {
      {
        "<C-CR>",
        'copilot#Accept("<CR>")',
        desc = "Copilot - Accept Suggestion",
        mode = { "i" },
      },
      {
        "<leader>ce",
        'copilot#Dismiss()',
        desc = "Copilot - Dismiss Suggestion",
        mode = { "i" },
      },
      {
        "<leader><C-n>",
        'copilot#Next()',
        desc = "Copilot - Next Suggestion",
        mode = { "i" },
      },
      {
        "<leader><C-p>",
        'copilot#Previous()',
        desc = "Copilot - Previous Suggestion",
        mode = { "i" },
      },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "CopilotChat",
    branch = "main",
    build = "make tiktoken",
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        auto_insert_mode = true,
        question_header = "  " .. user .. " ",
        answer_header = "  Copilot ",
        window = {
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
