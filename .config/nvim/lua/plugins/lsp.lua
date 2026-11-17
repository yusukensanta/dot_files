-- LSP core, shared by every language. It names no language itself: each
-- lua/plugins/lang/<language>.lua adds its servers to `opts.servers` and its
-- Mason packages to mason-tool-installer's `ensure_installed`.
--
-- Servers are enabled with vim.lsp.enable(), which starts a server only in
-- buffers whose filetype is in that server's `filetypes` — so a server never
-- runs for unrelated files. Enabling happens on BufReadPre/BufNewFile,
-- before the first buffer's FileType event, so the file nvim was started
-- with gets its servers too.
return {
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonUpdate", "MasonLog", "MasonInstall", "MasonUninstall", "MasonUninstallAll" },
    opts = {
      ui = {
        -- border inherited from 'winborder'
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
    keys = {
      { "<leader>ma", "<cmd>Mason<cr>", desc = "Mason - Open" },
    },
  },

  {
    -- Installs every Mason package the language files list (servers,
    -- formatters, linters, debug adapters), in the background after startup.
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {},
      -- Package names are Mason's own; no mason-lspconfig name mapping.
      integrations = { ["mason-lspconfig"] = false, ["mason-null-ls"] = false, ["mason-nvim-dap"] = false },
    },
    config = function(_, opts)
      -- Two languages may share a package (e.g. codelldb).
      local seen, unique = {}, {}
      for _, name in ipairs(opts.ensure_installed) do
        if not seen[name] then
          seen[name] = true
          unique[#unique + 1] = name
        end
      end
      opts.ensure_installed = unique
      require("mason-tool-installer").setup(opts)
    end,
  },

  {
    -- Provides the per-server defaults (cmd, filetypes, root markers) that
    -- vim.lsp.config() merges the language files' settings into.
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    -- mason.setup() puts Mason's bin dir on PATH, where the servers are.
    dependencies = { "mason-org/mason.nvim" },
    ---@type { servers: table<string, vim.lsp.Config|false> }
    opts = { servers = {} },
    config = function(_, opts)
      require("helpers.lsp").setup_attach()
      for name, server in pairs(opts.servers) do
        if server then
          if next(server) then
            vim.lsp.config(name, server)
          end
          vim.lsp.enable(name)
        end
      end
    end,
    keys = {
      { "<leader>lr", "<cmd>lsp restart<cr>", desc = "LSP: restart server" },
      { "<leader>li", "<cmd>lsp info<cr>", desc = "LSP: server info" },
    },
  },
}
