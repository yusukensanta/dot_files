return {
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      local lualine = require("lualine")
      lualine.setup({
        options = {
          icons_enabled = true,
          theme = 'tokyonight',
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {},
          always_divide_middle = true,
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = {
            "filename",
            { function() return vim.lsp.status() end },
          },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        extensions = {},
      })
    end,
  },
  {
    "romgrk/barbar.nvim",
    dependencies = {
      "lewis6991/gitsigns.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    branch = "master",
    config = function()
      require("barbar").setup({
        animation = true,
        auto_hide = false,
        clickable = true,
        closable = true,
        icons = {
          button = "✓",
          close_button = "x",
          filetype = {
            custom_colors = false,
            enabled = true,
          },
          separator = { left = "|", right = "" },
          separator_at_end = true,
          separator_at_start = false,
          gitsigns = {
            changed_italic = true,
            added = { enabled = true, icon = "+" },
            deleted = { enabled = true, icon = "✗" },
            changed = { enabled = true, icon = "~" },
          },
        },
        sort = {
          ignore_case = true,
        },
      })

      local map = require("helpers.keys").map
      map("n", "<leader>bn", "<cmd>BufferNext<cr>", "Next Buffer")
      map("n", "<leader>bp", "<cmd>BufferPrevious<cr>", "Previous Buffer")
      map("n", "<leader>bb", "<cmd>BufferPick<cr>", "Pick Buffer")
      map("n", "<leader>bc", "<cmd>BufferClose<cr>", "Close Buffer")
      map("n", "<leader>bl", "<cmd>BufferLast<cr>", "Last Buffer")
      map("n", "<leader>bs", "<cmd>BufferSelect<cr>", "Select Buffer")
    end,
  },
}
