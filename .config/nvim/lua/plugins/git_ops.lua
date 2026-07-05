-- Auto commands for git operations
local git_augroup = vim.api.nvim_create_augroup("GitOpsConfig", { clear = true })

vim.api.nvim_create_autocmd("User", {
  group = git_augroup,
  pattern = "GitConflictDetected",
  callback = function()
    vim.notify("Conflict detected in " .. vim.fn.expand("<afile>"))
  end,
})

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
      local map = require("helpers.keys").map
      -- Additional buffer-local mappings
      map("n", "<leader>gj", function()
        if vim.wo.diff then return "]c" end
        vim.schedule(function() gs.nav_hunk("next") end)
        return "<Ignore>"
      end, "GitSigns - Next hunk")

      map("n", "<leader>gk", function()
        if vim.wo.diff then return "[c" end
        vim.schedule(function() gs.nav_hunk("prev") end)
        return "<Ignore>"
      end, "GitSigns - Previous hunk")
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
      "ibhagwan/fzf-lua",
    },
    config = function()
      require("neogit").setup({
        -- Modern enhancements
        graph_style = "unicode", -- "ascii", "unicode"
        integrations = {
          telescope = false,
          diffview = true,
          fzf_lua = true,
        },
      })
    end,
    keys = {
      { "<leader>gg",  "<cmd>Neogit<cr>",        desc = "Neogit - Open" },
      { "<leader>gcm", "<cmd>Neogit commit<cr>", desc = "Neogit - Commit" },
      { "<leader>gp",  "<cmd>Neogit push<cr>",   desc = "Neogit - Push" },
      { "<leader>gl",  "<cmd>Neogit log<cr>",    desc = "Neogit - Log" },
      { "<leader>gbr", "<cmd>Neogit branch<cr>", desc = "Neogit - Branch" },
      { "<leader>gs",  "<cmd>Neogit<cr>",        desc = "Neogit - Status" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
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
      { "<leader>hd", ":Gitsigns toggle_deleted<CR>",                   desc = "Gitsigns - Toggle deleted" },
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
      { "<leader>gbt", function() require("gitsigns").blame() end, desc = "Gitsigns: full buffer blame" },
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
}
