-- LSP Configuration Module
-- Handles common LSP setup, keymaps, and server initialization

local M = {}

-- Helper function to setup LSP servers using modern Neovim 0.11+ API
local function lsp_setup(server, opts)
  if opts and not vim.tbl_isempty(opts) then
    vim.lsp.config(server, opts)
  end
  vim.lsp.enable(server)
end

-- Setup common LSP keymaps and formatting on attach
function M.setup_lsp_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("NvimLspAttach", { clear = true }),
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

      -- Enable completion if formatting is supported
      if client:supports_method("textDocument/formatting") then
        vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
      end

      -- Auto-format on save (except for languages with special handling)
      local exclude_filetypes = {
        "go",        -- Handled by go.lua (organize imports + gofumpt)
        "python",    -- Handled by python.lua (organize imports + ruff)
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
      }

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("NvimLspFormat", { clear = false }),
        buffer = args.buf,
        callback = function()
          local filetype = vim.bo[args.buf].filetype
          local should_skip = vim.tbl_contains(exclude_filetypes, filetype)

          if not should_skip then
            vim.lsp.buf.format({ async = false, bufnr = args.buf, id = client.id })
          end
        end,
      })

      -- LSP Keymaps
      local map = require("helpers.keys").lsp_map

      -- Navigation (gd/gD are custom; gi/gr/go/K/[d/]d removed — 0.12 built-in defaults)
      -- Built-in defaults: K=hover, grn=rename, grr=references, gra=code_action,
      --   gri=implementation, grt=type_definition, gO=document_symbol, [d/]d=diagnostics
      map("n", "gd", vim.lsp.buf.definition, "Go to Definition")
      map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")

      -- Information display
      map("n", "L", vim.lsp.buf.signature_help, "Show Signature Help")
      map("i", "<M-l>", vim.lsp.buf.signature_help, "Show Signature Help (Insert)")

      -- Code actions and refactoring (supplements built-in gra/grn)
      map({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, "Code Action")
      map("n", "<leader>rn", vim.lsp.buf.rename, "Rename Symbol")

      -- Workspace management
      map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add Workspace Folder")
      map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove Workspace Folder")
      map("n", "<leader>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, "List Workspace Folders")

      -- Document symbols and formatting (supplements built-in gO)
      map("n", "<leader>ds", vim.lsp.buf.document_symbol, "Document Symbols")
      map("n", "<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace Symbols")
      map({ "n", "v" }, "<leader>gf", function()
        vim.lsp.buf.format({ async = true })
      end, "Format Document/Selection")

      -- Diagnostics (supplements built-in [d/]d)
      map("n", "<leader>q", vim.diagnostic.setloclist, "Open Diagnostic List")

      -- Enhanced diagnostic display
      map("n", "<leader>dd", function()
        vim.diagnostic.enable(not vim.diagnostic.is_enabled())
      end, "Toggle Diagnostics")
    end,
  })
end

-- Load and setup all LSP servers
function M.setup_servers()
  -- Load server configurations
  local python = require("plugins.lsp.servers.python")
  local go = require("plugins.lsp.servers.go")
  local clangd = require("plugins.lsp.servers.clangd")
  local lua = require("plugins.lsp.servers.lua")
  local typescript = require("plugins.lsp.servers.typescript")

  -- Setup Python servers (basedpyright + ruff)
  lsp_setup("basedpyright", python.basedpyright)
  lsp_setup("ruff", python.ruff)
  python.setup_autocmds() -- Setup Python-specific formatting

  -- Setup Go servers (gopls + golangci-lint-langserver)
  lsp_setup("gopls", go.gopls)
  lsp_setup("golangci_lint_ls", go.golangci_lint_ls)
  go.setup_autocmds() -- Setup Go-specific formatting

  -- Setup C/C++ server (clangd)
  lsp_setup("clangd", clangd.clangd)

  -- Setup Lua server (lua_ls)
  lsp_setup("lua_ls", lua.lua_ls)

  -- Setup TypeScript/JavaScript server (ts_ls)
  lsp_setup("ts_ls", typescript.ts_ls)
end

return M
