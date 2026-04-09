-- rustaceanvim - Modern Rust development with rust-analyzer
-- Replaces rust-tools.nvim with better LSP integration
return {
  "mrcjkb/rustaceanvim",
  version = "^6", -- Recommended to use a version tag
  lazy = false, -- This plugin is already lazy
  ft = { "rust" },
  config = function()
    vim.g.rustaceanvim = {
      -- Plugin configuration
      tools = {
        -- Inlay hints are configured via rust-analyzer settings below
      },

      -- LSP configuration
      server = {
        on_attach = function(client, bufnr)
          -- Load common LSP keymaps if available
          local ok, lsp_config = pcall(require, "plugins.lsp.config")
          if ok and lsp_config.on_attach then
            lsp_config.on_attach(client, bufnr)
          end

          -- Rust-specific keymaps using helpers.keys
          local map = require("helpers.keys").buffer_map

          -- Hover actions
          map("n", "K", function()
            vim.cmd.RustLsp({ "hover", "actions" })
          end, "Rust hover actions", bufnr)

          -- Code actions
          map("n", "<leader>ca", function()
            vim.cmd.RustLsp("codeAction")
          end, "Rust code actions", bufnr)

          -- Runnables
          map("n", "<leader>rr", function()
            vim.cmd.RustLsp("runnables")
          end, "Rust runnables", bufnr)

          -- Debuggables
          map("n", "<leader>rd", function()
            vim.cmd.RustLsp("debuggables")
          end, "Rust debuggables", bufnr)

          -- Expand macro
          map("n", "<leader>re", function()
            vim.cmd.RustLsp("expandMacro")
          end, "Rust expand macro", bufnr)

          -- Open Cargo.toml
          map("n", "<leader>rc", function()
            vim.cmd.RustLsp("openCargo")
          end, "Open Cargo.toml", bufnr)

          -- Parent module
          map("n", "<leader>rp", function()
            vim.cmd.RustLsp("parentModule")
          end, "Go to parent module", bufnr)

          -- Join lines
          map("n", "J", function()
            vim.cmd.RustLsp("joinLines")
          end, "Join lines", bufnr)
        end,

        default_settings = {
          -- rust-analyzer settings
          ["rust-analyzer"] = {
            -- Enable clippy on save
            checkOnSave = {
              command = "clippy",
              extraArgs = {
                "--all-targets",
                "--all-features",
                "--",
                "-W",
                "clippy::all",
              },
            },

            -- Cargo settings
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },

            -- Proc macro support
            procMacro = {
              enable = true,
              attributes = {
                enable = true,
              },
            },

            -- Inlay hints
            inlayHints = {
              bindingModeHints = {
                enable = true,
              },
              chainingHints = {
                enable = true,
              },
              closingBraceHints = {
                enable = true,
                minLines = 25,
              },
              closureReturnTypeHints = {
                enable = "always",
              },
              lifetimeElisionHints = {
                enable = "always",
                useParameterNames = true,
              },
              parameterHints = {
                enable = true,
              },
              typeHints = {
                enable = true,
              },
            },

            -- Diagnostics
            diagnostics = {
              enable = true,
              experimental = {
                enable = true,
              },
            },

            -- Formatting (rustfmt)
            rustfmt = {
              -- Uses stable rustfmt by default
              -- Add "+nightly" to extraArgs if nightly toolchain is installed
              rangeFormatting = {
                enable = true,
              },
            },

            -- Completion
            completion = {
              autoimport = {
                enable = true,
              },
              postfix = {
                enable = true,
              },
            },

            -- Lens (code lens for showing references, implementations, etc.)
            lens = {
              enable = true,
              references = {
                adt = { enable = true },
                enumVariant = { enable = true },
                method = { enable = true },
                trait = { enable = true },
              },
              implementations = {
                enable = true,
              },
            },
          },
        },
      },

      -- DAP configuration (debugging)
      -- Uses codelldb from Mason
      dap = {
        adapter = {
          type = "server",
          port = "${port}",
          host = "127.0.0.1",
          executable = {
            command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb",
            args = { "--port", "${port}" },
          },
        },
      },
    }
  end,
}
