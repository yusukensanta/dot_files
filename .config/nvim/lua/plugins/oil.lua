return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("oil").setup({
        columns = {
          "icon",
          "permissions",
          "size",
          "mtime",
        },
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<space>ov"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
          ["<space>oh"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
          ["<space>ot"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["<C-l>"] = "actions.refresh",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
        },
        use_default_keymaps = false,
        delete_to_trash = true,
        view_options = {
          show_hidden = true,
          natural_order = true,
          is_always_hidden = function(name, bufnr)
            return false
          end,
        },
      })

      local map = require("helpers.keys").map
      map("n", "<space>o", ":Oil<CR>", "Oil - Open file manager")
    end,
  }
}
