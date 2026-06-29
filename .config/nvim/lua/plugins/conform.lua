-- conform.nvim - Unified formatting interface
-- Works alongside LSP formatters as a fallback/alternative
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      -- Python: Use ruff for formatting
      -- Note: python.lua already configures ruff LSP formatting
      -- This serves as explicit fallback
      python = { "ruff_format" },

      -- JavaScript/TypeScript/React/JSON: Use biome ONLY
      -- Note: format.lua already has biome on save
      -- This provides conform interface for manual formatting
      javascript = { "biome" },
      typescript = { "biome" },
      javascriptreact = { "biome" },
      typescriptreact = { "biome" },
      json = { "biome" },
      jsonc = { "biome" },

      -- Rust: Use rustfmt (via rust-analyzer LSP preferred)
      -- This is fallback if LSP formatting is not available
      rust = { "rustfmt" },

      -- Additional languages with standard formatters
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      markdown = { "prettier" },
      yaml = { "prettier" },
      toml = { "taplo" },
    },

    -- Format on save configuration
    -- This is disabled by default to avoid conflicts with LSP formatting
    -- Individual language configs (go.lua, python.lua, etc.) handle format on save
    format_on_save = function(bufnr)
      -- Disable for languages that have LSP format on save configured
      local disable_filetypes = { "go", "python" }
      if vim.tbl_contains(disable_filetypes, vim.bo[bufnr].filetype) then
        return nil
      end

      -- For JS/TS/JSON, format.lua already handles it via biome
      -- Skip conform formatting to avoid double formatting
      local biome_filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "json", "jsonc" }
      if vim.tbl_contains(biome_filetypes, vim.bo[bufnr].filetype) then
        return nil
      end

      -- Format other filetypes on save
      return {
        timeout_ms = 500,
        lsp_format = "fallback",
      }
    end,

    -- Formatter configurations
    formatters = {
      shfmt = {
        -- -i 4   : 4-space indentation (0 = tabs)
        -- -ci    : indent switch case bodies
        -- -bn    : binary ops (&&, ||, |) at start of next line
        -- -sr    : redirect operators at end of line (default), or use -s for short functions
        prepend_args = { "-i", "4", "-ci", "-bn" },
      },
      biome = {
        command = function()
          local project_biome = vim.fn.findfile("node_modules/.bin/biome", ".;")
          if project_biome ~= "" then
            return vim.fn.fnamemodify(project_biome, ":p")
          end
          if vim.fn.executable("biome") == 1 then
            return "biome"
          end
          return "npx"
        end,
        args = function()
          local project_biome = vim.fn.findfile("node_modules/.bin/biome", ".;")
          local has_local = project_biome ~= "" or vim.fn.executable("biome") == 1
          local base_args = { "format", "--config-path", vim.fn.expand("~/.config/nvim"), "--write", "$FILENAME" }
          if has_local then
            return base_args
          end
          local npx_args = { "--yes", "@biomejs/biome@2.3.8" }
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

  -- Keymaps for manual formatting
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
}
