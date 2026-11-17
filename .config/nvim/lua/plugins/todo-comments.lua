-- todo-comments.nvim — highlight and search TODO/FIXME/HACK/NOTE comments
-- Integrates with trouble.nvim and fzf-lua (both already installed).
return {
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPost",
    opts = {
      signs = true,
      highlight = {
        multiline = false,
        before = "",
        keyword = "wide",
        after = "fg",
        pattern = [[.*<(KEYWORDS)\s*:]],
      },
      search = {
        command = "rg",
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--hidden",
          "-g", "!.git",
        },
      },
    },
    -- No ]T/[T jumps: those are Neovim's :tlast/:tfirst. Browse TODOs
    -- through the lists below instead.
    keys = {
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "Trouble: TODO list" },
      { "<leader>tt", "<cmd>TodoFzfLua<cr>", desc = "Fzf: search TODOs" },
    },
  },
}
