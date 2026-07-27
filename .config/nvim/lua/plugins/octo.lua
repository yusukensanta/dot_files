-- GitHub PR workflow (create/list/review/merge) via `gh` CLI
return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      picker = "fzf-lua",
      default_merge_method = "squash",
    },
    keys = {
      { "<leader>gop", "<cmd>Octo pr list<cr>",       desc = "Octo - PR list" },
      { "<leader>goc", "<cmd>Octo pr create<cr>",     desc = "Octo - PR create" },
      { "<leader>goR", "<cmd>Octo review start<cr>",  desc = "Octo - Review start" },
      { "<leader>goS", "<cmd>Octo review submit<cr>", desc = "Octo - Review submit" },
      { "<leader>gom", "<cmd>Octo pr merge<cr>",      desc = "Octo - PR merge" },
      { "<leader>gox", "<cmd>Octo pr checks<cr>",     desc = "Octo - PR checks" },
    },
  },
}
