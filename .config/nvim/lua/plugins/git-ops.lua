-- Auto commands for git operations
local git_augroup = vim.api.nvim_create_augroup("GitOpsConfig", { clear = true })

vim.api.nvim_create_autocmd("User", {
  group = git_augroup,
  pattern = "GitConflictDetected",
  callback = function()
    vim.notify("Conflict detected in " .. vim.fn.expand("<afile>"))
  end,
})

-- No forced `Gitsigns refresh` on BufEnter/FocusGained: gitsigns watches the
-- git dir itself and updates its signs on write.

-- Next/prev hunk navigation with diff-mode fallback lives on `]c`/`[c` in the
-- gitsigns plugin spec below (its `keys` table sets expr = true).

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
      diff_opts = {
        algorithm = "patience",
        internal = true,
      },
    },
    keys = {
      -- n and x: in Visual mode the command gets the selected lines as its
      -- range, staging/resetting only those. stage_hunk on a staged hunk
      -- unstages it (replaces the deprecated undo_stage_hunk).
      { "<leader>hs", ":Gitsigns stage_hunk<CR>", mode = { "n", "x" }, desc = "Gitsigns - Stage/unstage hunk" },
      { "<leader>hr", ":Gitsigns reset_hunk<CR>", mode = { "n", "x" }, desc = "Gitsigns - Reset hunk" },
      { "<leader>hS", ":Gitsigns stage_buffer<CR>",                     desc = "Gitsigns - Stage buffer" },
      { "<leader>hR", ":Gitsigns reset_buffer<CR>",                     desc = "Gitsigns - Reset buffer" },
      { "<leader>hp", ":Gitsigns preview_hunk<CR>",                     desc = "Gitsigns - Preview hunk" },
      { "<leader>hb", ":Gitsigns blame_line<CR>",                       desc = "Gitsigns - Blame line" },
      { "<leader>ht", ":Gitsigns diffthis<CR>",                         desc = "Gitsigns - Diff this" },
      { "<leader>hD", function() require("gitsigns").diffthis("~") end, desc = "Gitsigns - Diff this ~" },
      { "<leader>hd", ":Gitsigns preview_hunk_inline<CR>",              desc = "Gitsigns - Preview hunk inline" },
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
    -- akinsho/git-conflict.nvim is stale (main pinned at 2024-12-27, no
    -- merged commits since). Pulling from evanpurkhiser's PR branch instead
    -- of upstream main — https://github.com/akinsho/git-conflict.nvim/pull/126
    -- replaces the removed vim.highlight and deprecated table-style
    -- vim.validate{} calls with the current APIs (pure rename, no behavior
    -- change). Revert to "akinsho/git-conflict.nvim" once #126 merges.
    "evanpurkhiser/git-conflict.nvim",
    branch = "evanpurkhiser/fix-deprecated-apis",
    -- Pinned to the reviewed commit: the branch is a PR head and can move or
    -- be deleted at any time.
    commit = "3df003abb53fc684ffe5d38da7370cc451f48462",
    event = "BufReadPre",
    config = function()
      require("git-conflict").setup({
        -- Off: the plugin's buffer-local co/ct/cb/c0 shadow the c operator
        -- (ct{char}, cb, ...) in conflicted buffers. The <leader>gx* and
        -- ]x/[x keys below cover the same actions.
        default_mappings = false,
        default_commands = true,
        disable_diagnostics = false,
        list_opener = "copen",
        highlights = {
          incoming = "DiffAdd",
          current = "DiffText",
          ancestor = "DiffChange",
        },
      })
    end,
    keys = {
      { "<leader>gxl", "<cmd>GitConflictListQf<cr>",         desc = "Git Conflict - List conflicts" },
      { "<leader>gxo", "<Plug>(git-conflict-ours)",          desc = "Git Conflict - Choose ours" },
      { "<leader>gxt", "<Plug>(git-conflict-theirs)",        desc = "Git Conflict - Choose theirs" },
      { "<leader>gxb", "<Plug>(git-conflict-both)",          desc = "Git Conflict - Choose both" },
      { "<leader>gxn", "<Plug>(git-conflict-none)",          desc = "Git Conflict - Choose none" },
      { "]x",          "<Plug>(git-conflict-next-conflict)", desc = "Git Conflict - Next conflict" },
      { "[x",          "<Plug>(git-conflict-prev-conflict)", desc = "Git Conflict - Prev conflict" },
    },
  },
  {
    "linrongbin16/gitlinker.nvim",
    cmd = "GitLink",
    opts = {},
    keys = {
      { "<leader>gy", "<cmd>GitLink<cr>",  mode = { "n", "x" }, desc = "GitLinker - Yank git link" },
      { "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "x" }, desc = "GitLinker - Open git link" },
    },
  },
}
