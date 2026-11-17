-- Rust: rustaceanvim (rust-analyzer with clippy on save), rustfmt, codelldb,
-- cargo test via neotest. Buffer options: after/ftplugin/rust.lua.
--
-- rust-analyzer comes from the project's own toolchain (rustup component),
-- never from Mason: the server then always matches the compiler, std
-- sources (rust-src) and proc-macro ABI the project pins in
-- rust-toolchain.toml. mise must read that file for this to hold — see the
-- `idiomatic_version_file_enable_tools` setting in scripts/install_libraries.sh.
-- It is not in lsp.lua's server list either, so only rustaceanvim starts it.
--
-- Missing guard, inherent to rust-analyzer itself (not specific to this
-- config): build scripts and proc-macros are enabled by default, so opening
-- or saving any .rs file compiles and runs that crate's build.rs and
-- proc-macros automatically — i.e. arbitrary code execution from project
-- content, with no trust prompt. check.command = "clippy" (below) likewise
-- runs on every save. Left enabled because disabling either breaks normal
-- Rust editing (macro-heavy code needs proc-macro expansion to resolve
-- correctly) — worth knowing before opening an unfamiliar Rust repo.
--
-- Debugging: rustaceanvim finds Mason's codelldb on its own, so no adapter
-- is configured here.
local warned_missing_ra = false

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9", -- v9 requires Neovim 0.12+
    -- vim.g.rustaceanvim must exist before rustaceanvim's ftplugin runs;
    -- lazy.nvim runs config() first, then re-fires FileType for the plugin.
    ft = "rust",
    config = function()
      vim.g.rustaceanvim = {
        tools = {
          -- Inlay hints are configured via rust-analyzer settings below
        },

        server = {
          -- Same command rustaceanvim would run, plus an actionable message
          -- when the active toolchain has no rust-analyzer: rustup's proxy
          -- otherwise fails with a bare "unavailable for the active
          -- toolchain" that only shows up in the LSP log. rustaceanvim may
          -- call this more than once per start, hence the once-only flag.
          cmd = function()
            if not warned_missing_ra and vim.fn.executable("rustup") == 1 then
              local res = vim.system({ "rustup", "which", "rust-analyzer" }, { text = true }):wait()
              if res.code ~= 0 then
                warned_missing_ra = true
                vim.notify(
                  "rust-analyzer is not installed for this toolchain. Run:\n"
                    .. "  rustup component add rust-analyzer rust-src",
                  vim.log.levels.ERROR
                )
              end
            end
            return { "rust-analyzer" }
          end,

          on_attach = function(client, bufnr)
            -- Common LSP keymaps come from the shared LspAttach handler
            -- (helpers/lsp.lua); code actions stay on its <space>ca / gra.
            local map = require("helpers.keys").buffer_map

            map("n", "K", function()
              vim.cmd.RustLsp({ "hover", "actions" })
            end, "Rust hover actions", bufnr)

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
              cargo = {
                features = "all",
                -- Build into target/rust-analyzer instead of target/, so the
                -- check on save never waits on (or invalidates the cache of)
                -- a `cargo build`/`cargo test` running in a terminal.
                targetDir = true,
              },

              -- The check on save runs what CI runs:
              -- `cargo clippy --workspace --all-targets --all-features`
              -- (features come from cargo.features above). Lint levels come
              -- from the project's [lints] tables only, so the editor and CI
              -- agree on what is a warning.
              check = {
                command = "clippy",
                allTargets = true,
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

              -- No rustfmt.rangeFormatting: it needs a nightly rustfmt, and
              -- the toolchains here are stable.

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
      }
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "codelldb" } },
  },
  {
    "stevearc/conform.nvim",
    -- The toolchain's rustfmt (rustup proxy), with the edition read from
    -- Cargo.toml (workspace-inherited editions included) — the same
    -- result as `cargo fmt`.
    opts = { formatters_by_ft = { rust = { "rustfmt" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust" } },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "mrcjkb/rustaceanvim" },
    -- rustaceanvim's adapter runs tests the way rust-analyzer's runnables
    -- do (cargo test, or cargo-nextest when installed).
    opts = { adapters = { ["rustaceanvim.neotest"] = {} } },
  },
}
