-- What every language server gets on attach, whatever the language:
-- keymaps and inlay hints. Language-specific attach behaviour lives in that
-- language's lua/plugins/lang/<language>.lua.
local M = {}

local function set_keymaps(bufnr)
  -- bufnr passed explicitly (not the buffer=true default): LspAttach fires
  -- for whichever buffer just attached, which isn't always the current one.
  local function map(mode, lhs, rhs, desc)
    require("helpers.keys").lsp_map(mode, lhs, rhs, desc, bufnr)
  end

  -- Navigation (gd/gD are custom; gi/gr/go/K/[d/]d removed — 0.12 built-in defaults)
  -- Built-in defaults: K=hover, grn=rename, grr=references, gra=code_action,
  --   gri=implementation, grt=type_definition, gO=document_symbol, [d/]d=diagnostics
  map("n", "gd", vim.lsp.buf.definition, "Go to Definition")
  map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")

  map("n", "L", vim.lsp.buf.signature_help, "Show Signature Help")
  map("i", "<M-l>", vim.lsp.buf.signature_help, "Show Signature Help (Insert)")

  -- Code actions and refactoring (supplements built-in gra/grn)
  map({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, "Code Action")
  map("n", "<leader>rn", vim.lsp.buf.rename, "Rename Symbol")

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
  map("n", "<leader>dd", function()
    vim.diagnostic.enable(not vim.diagnostic.is_enabled())
  end, "Toggle Diagnostics")

  map("n", "<leader>uh", function()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
  end, "Toggle Inlay Hints")
end

-- Registers the LspAttach handler. Called once by the LSP core spec.
function M.setup_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("NvimLspAttach", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end
      set_keymaps(args.buf)
      -- Servers whose hints are configured (rust-analyzer, ts_ls, clangd,
      -- ...) show them from the start; <leader>uh toggles per buffer.
      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      end
    end,
  })
end

return M
