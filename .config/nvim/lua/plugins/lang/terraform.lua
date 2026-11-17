-- Terraform: terraform-ls (validation, completion), `terraform fmt`. The
-- terraform binary itself comes from mise (install_libraries.sh).
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { terraformls = {} } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "terraform-ls" } },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        terraform = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "hcl", "terraform" } },
  },
}
