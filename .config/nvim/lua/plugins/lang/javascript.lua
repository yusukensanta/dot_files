-- JavaScript / TypeScript (and JSON, which Biome also formats): ts_ls for
-- types and completion, Biome for formatting.
--
-- Biome follows the project's biome.json(c) when there is one, so the
-- result matches `biome format` / CI in that project. Elsewhere it falls
-- back to this config's biome.json.
--
-- Missing guard, by design of how the binary is found: conform prefers
-- node_modules/.bin/biome (searching up from the file) over Mason's.
-- Saving a JS/TS/JSON file in any repo — including an untrusted,
-- freshly-cloned one — executes that binary with no confirmation prompt.
local biome_fts = { "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc" }

local inlay_hints = {
  includeInlayParameterNameHints = "all",
  includeInlayParameterNameHintsWhenArgumentMatchesName = false,
  includeInlayFunctionParameterTypeHints = true,
  includeInlayVariableTypeHints = true,
  includeInlayPropertyDeclarationTypeHints = true,
  includeInlayFunctionLikeReturnTypeHints = true,
  includeInlayEnumMemberValueHints = true,
}

local formatters_by_ft = {}
for _, ft in ipairs(biome_fts) do
  formatters_by_ft[ft] = { "biome" }
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ts_ls = {
          on_attach = function(client)
            -- Formatting is Biome's (through conform)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
          settings = {
            typescript = { inlayHints = inlay_hints },
            javascript = { inlayHints = inlay_hints },
          },
        },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "typescript-language-server", "biome" } },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = formatters_by_ft,
      formatters = {
        biome = {
          -- Extends conform's built-in biome formatter, whose cwd is the
          -- directory holding the project's biome.json(c) (nil when there
          -- is none): without one, use this config's biome.json.
          args = function(self, ctx)
            local args = { "format", "--stdin-file-path", "$FILENAME" }
            if not self:cwd(ctx) then
              vim.list_extend(args, { "--config-path", vim.fn.stdpath("config") })
            end
            return args
          end,
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "javascript", "typescript", "tsx", "json" } },
  },
}
