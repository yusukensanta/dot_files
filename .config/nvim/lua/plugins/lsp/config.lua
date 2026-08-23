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

-- Setup common LSP keymaps on attach.
--
-- Format-on-save is NOT set up here. It used to be a per-buffer BufWritePre
-- autocmd in this file, gated by its own exclude_filetypes list — but that
-- list and conform.lua's disable_filetypes/biome_filetypes lists were two
-- independently-maintained skip-lists that didn't cover the same set, and
-- any filetype in neither (c/cpp via clangd, concretely) got formatted
-- twice on every save: once here, once by conform's own format_on_save
-- fallback. conform.nvim (event = "BufWritePre", lsp_format = "fallback"
-- for anything without its own formatter) is the single format-on-save
-- owner now for everything except go/python (go.lua/python.lua run their
-- own organize-imports-then-format flow) and the js/ts/json family
-- (format.lua's biome integration) — both already excluded in
-- conform.lua's disable_filetypes/biome_filetypes.
function M.setup_lsp_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("NvimLspAttach", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then return end

      -- LSP Keymaps. bufnr passed explicitly (not the buffer=true default)
      -- since LspAttach fires for whichever buffer just finished
      -- attaching, which isn't guaranteed to be the current buffer.
      local function map(mode, lhs, rhs, desc)
        require("helpers.keys").lsp_map(mode, lhs, rhs, desc, args.buf)
      end

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
      map({ "n", "v" }, "<leader>lf", function()
        vim.lsp.buf.format({ async = true })
      end, "Format Document/Selection (LSP)")

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
