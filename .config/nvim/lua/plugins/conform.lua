-- conform.nvim - Unified formatting interface
-- The single format-on-save owner for everything except go/python
-- (go.lua/python.lua run their own organize-imports-then-format flow) and
-- the js/ts/json family (config/autocmds.lua's biome integration, both
-- excluded below). See the comment on setup_lsp_attach in lsp/config.lua
-- for why there's no second, generic LSP-attach format-on-save path.
return {
  {
    -- Installs the formatters conform.lua references below (stylua,
    -- shfmt, prettier, taplo) via Mason, the same way mason-nvim-dap.nvim
    -- (dap.lua) auto-installs DAP adapters and mason-lspconfig
    -- auto-installs LSP servers (lsp/init.lua) — without this, a fresh
    -- machine has conform.lua pointing at formatters nothing installed.
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = { "stylua", "shfmt", "prettier", "taplo" },
    },
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      notify_on_error = true,
      formatters_by_ft = {
        -- python.lua already runs ruff via LSP on save; this is only the
        -- manual-format (<leader>cf) / non-LSP-fallback path for it.
        python = { "ruff_format" },

        -- config/autocmds.lua already runs biome via BufWritePre; this is
        -- only the manual-format (<leader>cf) path for these filetypes.
        javascript = { "biome" },
        typescript = { "biome" },
        javascriptreact = { "biome" },
        typescriptreact = { "biome" },
        json = { "biome" },
        jsonc = { "biome" },

        rust = { "rustfmt" }, -- rust-analyzer's own LSP formatting is preferred when attached

        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        markdown = { "prettier" },
        yaml = { "prettier" },
        toml = { "taplo" },
      },

      -- Format on save. Everything not explicitly excluded below falls
      -- through to `lsp_format = "fallback"` — i.e. this function's `return`
      -- at the bottom is what makes conform the format-on-save owner for
      -- c/cpp (clangd), and anything else with an attached LSP formatter and
      -- no more specific handling.
      format_on_save = function(bufnr)
        -- go/python: go.lua/python.lua already run organize-imports-then-
        -- format on save themselves.
        local disable_filetypes = { "go", "python" }
        if vim.tbl_contains(disable_filetypes, vim.bo[bufnr].filetype) then
          return nil
        end

        -- config/autocmds.lua already formats these via biome (a dedicated
        -- vim.system + stdin/stdout integration, not conform's generic
        -- formatter interface — kept that way for its config-path handling).
        local biome_filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "json", "jsonc" }
        if vim.tbl_contains(biome_filetypes, vim.bo[bufnr].filetype) then
          return nil
        end

        return {
          timeout_ms = 500,
          lsp_format = "fallback",
        }
      end,

      formatters = {
        shfmt = {
          -- -i 4   : 4-space indentation (0 = tabs)
          -- -ci    : indent switch case bodies
          -- -bn    : binary ops (&&, ||, |) at start of next line
          -- -sr    : redirect operators at end of line (default), or use -s for short functions
          prepend_args = { "-i", "4", "-ci", "-bn" },
        },
        -- Resolution shared with config/autocmds.lua's biome BufWritePre
        -- pipeline via helpers/biome.lua (also documents the missing-guard
        -- tradeoff of running a project-local binary unprompted).
        biome = {
          command = require("helpers.biome").resolve_command,
          args = function()
            local biome_helper = require("helpers.biome")
            local base_args = { "format", "--config-path", vim.fn.expand("~/.config/nvim"), "--write", "$FILENAME" }
            if biome_helper.has_local() then
              return base_args
            end
            local npx_args = biome_helper.npx_bootstrap_args()
            vim.list_extend(npx_args, base_args)
            return npx_args
          end,
          stdin = false,
        },
        ruff_format = {
          command = "ruff",
          args = { "format", "--stdin-filename", "$FILENAME", "-" },
          stdin = true,
        },
      },
    },

    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
  },
}
