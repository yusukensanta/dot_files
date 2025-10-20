-- Additional key mappings for git operations
vim.api.nvim_create_autocmd("User", {
  pattern = "GitConflictDetected",
  callback = function()
    vim.notify("Conflict detected in " .. vim.fn.expand("<afile>"))
  end,
})
-- Auto commands for git operations
local git_augroup = vim.api.nvim_create_augroup("GitOpsConfig", { clear = true })

-- Auto refresh gitsigns when git state changes
local refresh_timer = nil
vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "FocusGained", "ShellCmdPost" }, {
  group = git_augroup,
  pattern = "*",
  callback = function()
    if refresh_timer then
      vim.fn.timer_stop(refresh_timer)
    end
    refresh_timer = vim.fn.timer_start(50, function()
      if vim.fn.exists(":Gitsigns") > 0 then
        vim.cmd("Gitsigns refresh")
      end
      refresh_timer = nil
    end)
  end,
})

-- Setup integration between plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsAttach",
  callback = function(args)
    -- Setup buffer-local keymaps when gitsigns attaches to a buffer
    local bufnr = args.buf
    local gs = package.loaded.gitsigns

    if gs then
      -- Additional buffer-local mappings
      vim.keymap.set("n", "<leader>gj", function()
        if vim.wo.diff then return "]c" end
        vim.schedule(function() gs.nav_hunk("next") end)
        return "<Ignore>"
      end, { expr = true, buffer = bufnr, desc = "Next hunk" })

      vim.keymap.set("n", "<leader>gk", function()
        if vim.wo.diff then return "[c" end
        vim.schedule(function() gs.nav_hunk("prev") end)
        return "<Ignore>"
      end, { expr = true, buffer = bufnr, desc = "Previous hunk" })
    end
  end,
})


return {
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("neogit").setup({
        -- Modern enhancements
        graph_style = "unicode", -- "ascii", "unicode"
        git_services = {
          ["github.com"] =
          "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
          ["bitbucket.org"] =
          "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
          ["gitlab.com"] =
          "https://gitlab.com/${owner}/${repository}/-/merge_requests/new?merge_request[source_branch]=${branch_name}",
        },
        telescope_sorter = function()
          return require("telescope").extensions.fzf.native_fzf_sorter()
        end,
        -- Your existing config with improvements
        disable_hint = false,
        disable_context_highlighting = false,
        disable_signs = false,
        prompt_force_push = true,
        commit_editor = {
          kind = "vsplit",
          show_staged_diff = true,
          staged_diff_split_kind = "vsplit", -- "split", "vsplit"
        },
        auto_refresh = true,
        sort_branches = "-committerdate",
        kind = "tab",
        integrations = {
          telescope = true,
          diffview = true,
          fzf_lua = true, -- New integration
        },
      })
    end,
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>",        desc = "Neogit - Open" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit - Commit" },
      { "<leader>gp", "<cmd>Neogit push<cr>",   desc = "Neogit - Push" },
      { "<leader>gl", "<cmd>Neogit log<cr>",    desc = "Neogit - Log" },
      { "<leader>gb", "<cmd>Neogit branch<cr>", desc = "Neogit - Branch" },
      { "<leader>gs", "<cmd>Neogit<cr>",        desc = "Neogit - Status" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
      },
      signs_staged_enable = true,
      signcolumn = true,
      watch_gitdir = {
        follow_files = true,
      },
      auto_attach = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 300, -- Faster response
        ignore_whitespace = false,
      },
      preview_config = {
        border = "rounded",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
      },
      -- Enhanced diff algorithm
      diff_opts = {
        algorithm = "patience",
        internal = true,
      },
    },
    keys = {
      { "<leader>hs", ":Gitsigns stage_hunk<CR>",                       desc = "Gitsigns - Stage hunk" },
      { "<leader>hr", ":Gitsigns reset_hunk<CR>",                       desc = "Gitsigns - Reset hunk" },
      { "<leader>hS", ":Gitsigns stage_buffer<CR>",                     desc = "Gitsigns - Stage buffer" },
      { "<leader>hu", ":Gitsigns undo_stage_hunk<CR>",                  desc = "Gitsigns - Undo stage hunk" },
      { "<leader>hR", ":Gitsigns reset_buffer<CR>",                     desc = "Gitsigns - Reset buffer" },
      { "<leader>hp", ":Gitsigns preview_hunk<CR>",                     desc = "Gitsigns - Preview hunk" },
      { "<leader>hb", ":Gitsigns blame_line<CR>",                       desc = "Gitsigns - Blame line" },
      { "<leader>ht", ":Gitsigns diffthis<CR>",                         desc = "Gitsigns - Diff this" },
      { "<leader>hD", function() require("gitsigns").diffthis("~") end, desc = "Gitsigns - Diff this ~" },
      { "<leader>td", ":Gitsigns toggle_deleted<CR>",                   desc = "Gitsigns - Toggle deleted" },
      {
        "]c",
        function()
          if vim.wo.diff then return "]c" end
          vim.schedule(function() require("gitsigns").nav_hunk("next") end)
          return "<Ignore>"
        end,
        expr = true,
        desc = "Next hunk"
      },
      {
        "[c",
        function()
          if vim.wo.diff then return "[c" end
          vim.schedule(function() require("gitsigns").nav_hunk("prev") end)
          return "<Ignore>"
        end,
        expr = true,
        desc = "Prev hunk"
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewRefresh", "DiffviewFileHistory" },
    config = function()
      require("diffview").setup({
        enhanced_diff_hl = true, -- Enable better diff highlighting
        use_icons = true,
        show_help_hints = true,
        view = {
          default = {
            layout = "diff2_horizontal",
            winbar_info = true, -- Show file info in winbar
          },
          merge_tool = {
            layout = "diff3_horizontal",
            disable_diagnostics = true,
            winbar_info = true,
          },
          file_history = {
            layout = "diff2_horizontal",
            winbar_info = true,
          },
        },
      })
    end,
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",          desc = "Diffview - Open" },
      { "<leader>gD", "<cmd>DiffviewClose<cr>",         desc = "Diffview - Close" },
      { "<leader>gF", "<cmd>DiffviewFileHistory<cr>",   desc = "Diffview - File" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview - Current File History" },
    },
  },
  {
    "akinsho/git-conflict.nvim",
    event = "BufReadPre",
    config = function()
      require("git-conflict").setup({
        default_mappings = {
          ours = "co",
          theirs = "ct",
          none = "c0",
          both = "cb",
          next = "]x",
          prev = "[x",
        },
        default_commands = true,
        disable_diagnostics = false,
        list_opener = "copen", -- Use quickfix list
        highlights = {
          incoming = "DiffAdd",
          current = "DiffText",
          ancestor = "DiffChange",
        },
      })
    end,
    keys = {
      { "<leader>gx",  "<cmd>GitConflictListQf<cr>",         desc = "Git Conflict - List conflicts" },
      { "<leader>gco", "<Plug>(git-conflict-ours)",          desc = "Git Conflict - Choose ours" },
      { "<leader>gct", "<Plug>(git-conflict-theirs)",        desc = "Git Conflict - Choose theirs" },
      { "<leader>gcb", "<Plug>(git-conflict-both)",          desc = "Git Conflict - Choose both" },
      { "<leader>gc0", "<Plug>(git-conflict-none)",          desc = "Git Conflict - Choose none" },
      { "]x",          "<Plug>(git-conflict-next-conflict)", desc = "Git Conflict - Next conflict" },
      { "[x",          "<Plug>(git-conflict-prev-conflict)", desc = "Git Conflict - Prev conflict" },
    },
  },
  -- 6. GITLINKER - Generate git permalinks
  {
    "linrongbin16/gitlinker.nvim",
    cmd = "GitLink",
    opts = {},
    keys = {
      { "<leader>gy", "<cmd>GitLink<cr>",  mode = { "n", "v" }, desc = "GitLinker - Yank git link" },
      { "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "GitLinker - Open git link" },
    },
  },
  {
    "aaronhallaert/advanced-git-search.nvim",
    cmd = { "AdvancedGitSearch" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "tpope/vim-fugitive",
      "sindrets/diffview.nvim",
    },
    keys = {
      { "<leader>gS", "<cmd>AdvancedGitSearch<cr>", desc = "Advanced Git Search" },
    },
  },

  {
    "f-person/git-blame.nvim",
    event = "BufReadPre",
    opts = {
      enabled = false, -- Enable on demand
      message_template = " <summary> • <date> • <author> • <<sha>>",
      date_format = "%m-%d-%Y %H:%M:%S",
      virtual_text_column = 1,
    },
    keys = {
      { "<leader>gbt", "<cmd>GitBlameToggle<cr>",        desc = "Git Blame - Toggle Git Blame" },
      { "<leader>gbo", "<cmd>GitBlameOpenCommitURL<cr>", desc = "Git Blame - Open Commit URL" },
    },
  },
}
