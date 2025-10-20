vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("NvimLspAttach", {}),
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

    if client:supports_method("textDocument/formatting") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true})
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("NvimLspFormat", { clear = false }),
      buffer = args.buf,
      callback = function()
        if vim.bo[args.buf].filetype ~= "go" then
          vim.lsp.buf.format({ async = false, bufnr = args.buf, id = client.id })
        end
      end,
    })

    local map = require("helpers.keys").lsp_map
    map("n", "gd", vim.lsp.buf.definition, "Go to Definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")
    map("n", "gi", vim.lsp.buf.implementation, "Go to Implementation")
    map("n", "gr", vim.lsp.buf.references, "Show References")
    map("n", "go", vim.lsp.buf.type_definition, "Go to Type Definition")

    -- Information display
    map("n", "K", vim.lsp.buf.hover, "Show Hover Information")
    map("n", "L", vim.lsp.buf.signature_help, "Show Signature Help")
    map("i", "<M-l>", vim.lsp.buf.signature_help, "Show Signature Help (Insert)")

    -- Code actions and refactoring
    map({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, "Code Action")
    map("n", "rn", vim.lsp.buf.rename, "Rename Symbol")

    -- Workspace management
    map("n", "wa", vim.lsp.buf.add_workspace_folder, "Add Workspace Folder")
    map("n", "wr", vim.lsp.buf.remove_workspace_folder, "Remove Workspace Folder")
    map("n", "wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "List Workspace Folders")

    -- Document symbols and formatting
    map("n", "ds", vim.lsp.buf.document_symbol, "Document Symbols")
    map("n", "<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace Symbols")
    map({ "n", "v" }, "<leader>gf", function()
      vim.lsp.buf.format({ async = true })
    end, "Format Document/Selection")

    map("n", "[d", vim.diagnostic.goto_prev, "Go to Previous Diagnostic")
    map("n", "]d", vim.diagnostic.goto_next, "Go to Next Diagnostic")
    map("n", "<leader>q", vim.diagnostic.setloclist, "Open Diagnostic List")

    -- Enhanced diagnostic display
    map("n", "<leader>dd", function()
      vim.diagnostic.enable(not vim.diagnostic.is_enabled())
    end, "Toggle Diagnostics")
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("GoFormat", { clear = true }),
  pattern = "*.go",
  callback = function(args)
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(args.buf, "textDocument/codeAction", params, 3000)
    if result then
      for _, res in pairs(result) do
        for _, r in pairs(res.result or {}) do
          if r.edit then
            vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
          end
        end
      end
    end

    vim.lsp.buf.format({ async = false, bufnr = args.buf })
  end,
})

local function lsp_setup(server, opts)
  if opts and not vim.tbl_isempty(opts) then
    vim.lsp.config(server, opts)
  end
  vim.lsp.enable(server)
end

return {
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = {
      "Mason",
      "MasonUpdate",
      "MasonLog",
      "MasonInstall",
      "MasonUninstall",
      "MasonUninstallAll",
    },
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          }
        }
      })
    end,
    keys = {
      { "<leader>ma", "<cmd>Mason<cr>", desc = "Mason - Open" },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "basedpyright",
          "ruff",
          "gopls",
          "clangd",
        }
      })

      local function setup_servers()
        lsp_setup("basedpyright", {
          settings = {
            basedpyright = {
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                typeCheckingMode = "off",
                diagnosticMode = "openFilesOnly",
                autoImportCompletions = false,
                diagnosticSeverityOverrides = {
                  reportMissingTypeStubs = false,
                  reportOptionalCall = false,
                  reportOptionalIterable = false,
                  reportOptionalMemberAccess = false,
                  reportOptionalOperand = false,
                  reportOptionalSubscript = false,
                  reportPrivateImportUsage = false,
                  reportUnboundVariable = false,
                },
              },
            },
          },
          on_attach = function(client, bufnr)
            client.server_capabilities.diagnosticProvider = false
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
        })
        lsp_setup("ruff", {
          init_options = {
            settings = {
              logLevel = "info",
              organizeImports = true,
              fixAll = true,
              lint = {
                enable = true,
                run = "onSave",
              },
              format = {
                enable = true,
              },
            },
          },
          on_attach = function(client, bufnr)
            client.server_capabilities.completionProvider = false
            client.server_capabilities.hoverProvider = false
          end
        })

        lsp_setup("lua_ls", {
          settings = {
            Lua = {
              runtime = {
                version = "LuaJIT",
              },
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = {
                enable = false,
              },
            },
          },
        })

        lsp_setup("gopls", {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow = true,
                fieldalignment = true,
              },
              staticcheck = true,
              gofumpt = true,
              usePlaceholders = true,
              completeUnimported = true,
              matcher = "Fuzzy",
              experimentalPostfixCompletions = true,
              codelenses = {
                gc_details = true,
                generate = true,
                regenerate_cgo = true,
                run_govulncheck = true,
                test = true,
                tidy = true,
                upgrade_dependency = true,
                vendor = true,
              },
            }
          }
        })

        lsp_setup("clangd", {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          root_markers = {
            ".clangd-format",
            ".git",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
          filetypes = { "c", "cpp" },
          settings = {
            clangd = {
              InlayHints = {
                Designators = true,
                Enabled = true,
                ParameterNames = true,
                DeducedTypes = true,
              },
            },
          },
        })
      end

      vim.schedule(setup_servers)

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("LspAttachDisableBasedPyright", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client == nil then return end
          if client == "basedpyright" then
            client.server_capabilities.hoverProvider = false
          end
        end,
        desc = "LSP(basedpyright) - disable hover capability from basedpyright",
      })
    end
  },
}
