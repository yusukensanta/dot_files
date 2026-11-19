return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- On-demand: only its own <leader>o keymap opens it (lazy.nvim sets the
    -- mapping and loads the plugin on first use).
    keys = {
      { "<leader>o", "<cmd>Oil<CR>", desc = "Oil - Open file manager" },
    },
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
          ["<leader>ov"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
          ["<leader>oh"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
          ["<leader>ot"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          -- Deliberately shadows the global <C-l> "move focus to right
          -- window" (config/keymaps.lua) inside Oil buffers only: a listing is
          -- normally the sole focus of its window, so refresh is more
          -- useful here than window nav. <C-w>l still works for
          -- moving right if you do need it from Oil.
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
    end,
  }
}
