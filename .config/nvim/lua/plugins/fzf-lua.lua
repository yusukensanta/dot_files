-- fzf-lua fuzzy finding (replaces telescope)
return {
  {
    "ibhagwan/fzf-lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    -- Also loads on VeryLazy (shortly after startup, not blocking the
    -- first frame) rather than purely on-keypress: config() below also
    -- calls fzf.register_ui_select(), which needs to have run before
    -- anything (e.g. an LSP code action) calls vim.ui.select — otherwise
    -- that falls back to the plain built-in picker until some fzf-lua
    -- keymap happens to fire first.
    event = "VeryLazy",
    -- These mirror the real bindings config() registers below (lazy.nvim's
    -- standard pattern: this copy is just a load trigger, replaced by the
    -- real one the moment config() runs).
    keys = {
      { "<leader>to", function() require("fzf-lua").oldfiles() end, desc = "Fzf - Recently opened" },
      { "<leader>tb", function() require("fzf-lua").buffers() end, desc = "Fzf - Open buffers" },
      { "<leader>/", function() require("fzf-lua").blines() end, desc = "Fzf - Search in current buffer" },
      { "<leader>tf", function() require("fzf-lua").files() end, desc = "Fzf - Files" },
      { "<leader>th", function() require("fzf-lua").help_tags() end, desc = "Fzf - Help" },
      { "<leader>tw", function() require("fzf-lua").grep_cword() end, desc = "Fzf - Current word" },
      { "<leader>tg", function() require("fzf-lua").live_grep() end, desc = "Fzf - Grep" },
      { "<leader>td", function() require("fzf-lua").diagnostics_workspace() end, desc = "Fzf - Diagnostics" },
      { "<leader>tk", function() require("fzf-lua").keymaps() end, desc = "Fzf - Search keymaps" },
      { "<leader>ts", function() require("fzf-lua").files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Fzf - Files in buffer directory" },
      { "<leader>tF", function() require("fzf-lua").git_files() end, desc = "Fzf - Git files" },
      { "<leader>tC", function() require("fzf-lua").git_commits() end, desc = "Fzf - Git commits" },
      { "<leader>tS", function() require("fzf-lua").git_status() end, desc = "Fzf - Git status" },
      { "<leader>tB", function() require("fzf-lua").git_branches() end, desc = "Fzf - Git branches" },
      { "<leader>tr", function() require("fzf-lua").resume() end, desc = "Fzf - Resume last search" },
      { "<leader>tW", function() require("fzf-lua").grep_cWORD() end, desc = "Fzf - Current WORD" },
      { "<leader>tv", function() require("fzf-lua").grep_visual() end, mode = "v", desc = "Fzf - Grep visual selection" },
    },
    config = function()
      local fzf = require("fzf-lua")

      fzf.setup({
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
        files = {
          fd_opts = [[--color=never --type f --hidden --follow --exclude .git --exclude node_modules --exclude .asdf --exclude .npm --exclude .local --exclude .cache --exclude .DS_Store --exclude .ruff_cache --exclude __pycache__]],
          rg_opts = [[--color=never --files --hidden --follow -g "!.git" -g "!node_modules" -g "!.asdf" -g "!.npm" -g "!.local" -g "!.cache" -g "!.DS_Store" -g "!.ruff_cache" -g "!__pycache__"]],
        },
        grep = {
          rg_opts = [[--color=never --no-heading --with-filename --line-number --column --smart-case --hidden -g "!.git" -g "!node_modules" -g "!.asdf" -g "!.npm" -g "!.local" -g "!.cache" -g "!.DS_Store" -g "!.ruff_cache" -g "!__pycache__"]],
        },
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

      fzf.register_ui_select()

      local map = require("helpers.keys").map

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

      map("n", "<leader>tr", fzf.resume, "Fzf - Resume last search")
      map("n", "<leader>tW", fzf.grep_cWORD, "Fzf - Current WORD")
      map("v", "<leader>tv", fzf.grep_visual, "Fzf - Grep visual selection")
    end,
  },
}
