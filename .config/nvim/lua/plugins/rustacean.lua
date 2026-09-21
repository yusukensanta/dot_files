-- rustaceanvim - Modern Rust development with rust-analyzer
-- Replaces rust-tools.nvim with better LSP integration
--
-- Missing guard, inherent to rust-analyzer itself (not specific to this
-- config): cargo.buildScripts.enable + procMacro.enable below mean opening
-- or saving any .rs file compiles and runs that crate's build.rs and
-- proc-macros automatically — i.e. arbitrary code execution from project
-- content, with no trust prompt. checkOnSave.command = "clippy" (below)
-- likewise runs on every save. Left enabled because disabling either breaks
-- normal Rust editing (macro-heavy code needs proc-macro expansion to
-- resolve correctly) — worth knowing before opening an unfamiliar Rust repo.
return {
  "mrcjkb/rustaceanvim",
  version = "^6", -- Recommended to use a version tag
  lazy = false, -- This plugin is already lazy
  ft = { "rust" },
  config = function()
    vim.g.rustaceanvim = {
      tools = {
        -- Inlay hints are configured via rust-analyzer settings below
      },

      server = {
        on_attach = function(client, bufnr)
          -- Common LSP keymaps are set via the global LspAttach autocmd in lsp/config.lua
          local map = require("helpers.keys").buffer_map

          map("n", "K", function()
            vim.cmd.RustLsp({ "hover", "actions" })
          end, "Rust hover actions", bufnr)

          map("n", "<leader>ca", function()
            vim.cmd.RustLsp("codeAction")
          end, "Rust code actions", bufnr)

          map("n", "<leader>rr", function()
            vim.cmd.RustLsp("runnables")
          end, "Rust runnables", bufnr)

          map("n", "<leader>rd", function()
            vim.cmd.RustLsp("debuggables")
          end, "Rust debuggables", bufnr)

          map("n", "<leader>re", function()
            vim.cmd.RustLsp("expandMacro")
          end, "Rust expand macro", bufnr)

          map("n", "<leader>rc", function()
            vim.cmd.RustLsp("openCargo")
          end, "Open Cargo.toml", bufnr)

          map("n", "<leader>rp", function()
            vim.cmd.RustLsp("parentModule")
          end, "Go to parent module", bufnr)

          map("n", "J", function()
            vim.cmd.RustLsp("joinLines")
          end, "Join lines", bufnr)
        end,

        default_settings = {
          ["rust-analyzer"] = {
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

            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },

            procMacro = {
              enable = true,
              attributes = {
                enable = true,
              },
            },

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

            diagnostics = {
              enable = true,
              experimental = {
                enable = true,
              },
            },

            rustfmt = {
              -- Add "+nightly" to extraArgs if a nightly toolchain is installed
              rangeFormatting = {
                enable = true,
              },
            },

            completion = {
              autoimport = {
                enable = true,
              },
              postfix = {
                enable = true,
              },
            },

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
