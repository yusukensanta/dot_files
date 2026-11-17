-- C / C++: clangd (diagnostics incl. clang-tidy, formatting with the
-- project's .clang-format through conform's LSP fallback).
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          root_markers = { ".clang-format", ".clangd", "compile_commands.json", ".git" },
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
        },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "clangd" } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c", "cpp" } },
  },
}
