-- fzf-lua fuzzy finding (replaces telescope)
return {
  {
    "ibhagwan/fzf-lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local fzf = require("fzf-lua")

      fzf.setup({
        -- Global settings
        winopts = {
          height = 0.85,
          width = 0.80,
          row = 0.35,
          col = 0.50,
          preview = {
            layout = "flex",
            flip_columns = 120,
          },
        },
        keymap = {
          builtin = {
            ["jj"] = "hide",         -- Close fzf-lua window
          },
          fzf = {
            ["ctrl-c"] = "abort",    -- Also keep ctrl-c for abort
          },
        },
        -- File ignore patterns (matching your telescope config)
        files = {
          fd_opts = [[--color=never --type f --hidden --follow --exclude .git --exclude node_modules --exclude .asdf --exclude .npm --exclude .local --exclude .cache --exclude .DS_Store --exclude .ruff_cache --exclude __pycache__]],
          rg_opts = [[--color=never --files --hidden --follow -g "!.git" -g "!node_modules" -g "!.asdf" -g "!.npm" -g "!.local" -g "!.cache" -g "!.DS_Store" -g "!.ruff_cache" -g "!__pycache__"]],
        },
        grep = {
          rg_opts = [[--color=never --no-heading --with-filename --line-number --column --smart-case --hidden -g "!.git" -g "!node_modules" -g "!.asdf" -g "!.npm" -g "!.local" -g "!.cache" -g "!.DS_Store" -g "!.ruff_cache" -g "!__pycache__"]],
        },
        -- Dropdown style for buffer search
        blines = {
          winopts = {
            height = 0.4,
            width = 0.6,
            row = 0.4,
            preview = {
              hidden = "hidden",
            },
          },
        },
      })

      -- Register fzf-lua as the UI select handler
      fzf.register_ui_select()

      local map = require("helpers.keys").map

      -- Preserve all telescope keybindings with fzf-lua equivalents
      map("n", "<leader>to", fzf.oldfiles, "Fzf - Recently opened")
      map("n", "<leader>tb", fzf.buffers, "Fzf - Open buffers")
      map("n", "<leader>/", fzf.blines, "Fzf - Search in current buffer")
      map("n", "<leader>tf", fzf.files, "Fzf - Files")
      map("n", "<leader>th", fzf.help_tags, "Fzf - Help")
      map("n", "<leader>tw", fzf.grep_cword, "Fzf - Current word")
      map("n", "<leader>tg", fzf.live_grep, "Fzf - Grep")
      map("n", "<leader>td", fzf.diagnostics_workspace, "Fzf - Diagnostics")
      map("n", "<leader>tk", fzf.keymaps, "Fzf - Search keymaps")
      map("n", "<leader>ts", function()
        fzf.files({ cwd = vim.fn.expand("%:p:h") })
      end, "Fzf - Files in buffer directory")
      map("n", "<leader>tF", fzf.git_files, "Fzf - Git files")
      map("n", "<leader>tC", fzf.git_commits, "Fzf - Git commits")
      map("n", "<leader>tS", fzf.git_status, "Fzf - Git status")
      map("n", "<leader>tB", fzf.git_branches, "Fzf - Git branches")

      -- Additional useful mappings
      map("n", "<leader>tr", fzf.resume, "Fzf - Resume last search")
      map("n", "<leader>tW", fzf.grep_cWORD, "Fzf - Current WORD")
      map("v", "<leader>tv", fzf.grep_visual, "Fzf - Grep visual selection")
    end,
  },
}
