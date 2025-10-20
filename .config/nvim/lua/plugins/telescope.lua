-- Telescope fuzzy finding (all the things)
return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
        branch = "main"
      },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = {
            ".git",
            ".asdf",
            "node_modules",
            ".npm",
            ".local",
            ".cache",
            ".DS_Store",
            ".ruff_cache",
            "__pycache__"
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden", --追加
          },
        },
        pickers = {
          find_files = {
            follow = true,
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
          },
          live_grep = {
            additional_args = { "--hidden" }
          },
        },
        extensions = {
          file_browser = {
            hijack_netrw = false,
          }
        },
      })

      -- Enable telescope fzf native, if installed
      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "file_browser")

      local map = require("helpers.keys").map
      local builtin = require("telescope.builtin")
      map("n", "<leader>to", builtin.oldfiles, "Telescope - Recently opened")
      map("n", "<leader>tb", builtin.buffers, "Telescope - Open buffers")
      map("n", "<leader>/", function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
          winblend = 10,
          previewer = false,
        }))
      end, "Telescope - Search in current buffer")

      map("n", "<leader>tf", builtin.find_files, "Telescope - Files")
      map("n", "<leader>th", builtin.help_tags, "Telescope - Help")
      map("n", "<leader>tw", builtin.grep_string, "Telescope - Current word")
      map("n", "<leader>tg", builtin.live_grep, "Telescope - Grep")
      map("n", "<leader>td", builtin.diagnostics, "Telescope - Diagnostics")
      map("n", "<leader>tk", builtin.keymaps, "Telescope - Search keymaps")
      map("n", "<leader>ts", ":Telescope file_browser path=%:p:h select_buffer=true<CR>", "Telescope - File browser")
      map("n", "<leader>tF", builtin.git_files, "Telescope - Git files")
      map("n", "<leader>tC", builtin.git_commits, "Telescope - Git commit")
      map("n", "<leader>tS", builtin.git_status, "Telescope - Git status")
      map("n", "<leader>tB", builtin.git_branches, "Telescope - Git branches")
    end,
  },
}
