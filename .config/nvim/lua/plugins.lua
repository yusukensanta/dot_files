local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

vim.cmd([[
  augroup lsp
  autocmd!
  autocmd FileType scala,sbt lua require("metals").initialize_or_attach(metals_config)
  augroup end
]])

-- ref: https://github.com/hisasann/neovim/blob/master/lua/plugins.lua
packer.startup(function(use)
  use "wbthomason/packer.nvim"
  use "nvim-lualine/lualine.nvim"    -- Statusline
  use "windwp/nvim-autopairs"        -- Autopairs, integrates with both cmp and treesitter
  use "kyazdani42/nvim-web-devicons" -- File icons
  use "ibhagwan/fzf-lua"
  use "nvim-lua/plenary.nvim"        -- Common utilities

  -- cmp plugins
  use "hrsh7th/nvim-cmp"    -- The completion plugin
  use "hrsh7th/cmp-buffer"  -- buffer completions
  use "hrsh7th/cmp-path"    -- path completions
  use "hrsh7th/cmp-cmdline" -- cmdline completions
  use "hrsh7th/cmp-nvim-lsp"
  use "hrsh7th/cmp-nvim-lua"
  use "onsails/lspkind-nvim"
  use "mfussenegger/nvim-dap"
  use "jay-babu/mason-nvim-dap.nvim"

  -- snippets
  use "L3MON4D3/LuaSnip"         --snippet engine
  use "saadparwaiz1/cmp_luasnip" -- snippet completions

  -- theme
  use "folke/tokyonight.nvim"
  use "crispgm/nvim-tabline"

  -- LSP
  use "neovim/nvim-lspconfig" -- enable LSP
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'
  use 'WhoIsSethDaniel/mason-tool-installer.nvim'
  use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters
  use 'scalameta/nvim-metals'

  -- formatter
  use "MunifTanjim/prettier.nvim"

  -- fuzzy finder
  use "nvim-telescope/telescope.nvim"
  use {
    "nvim-telescope/telescope-file-browser.nvim",
    requires = { "nvim-telecope/telescope.nvim", "nvim-lua/plenary.nvim" }
  }

  -- Treesitter
  use { "nvim-treesitter/nvim-treesitter", run = ':TSUpdate' }

  -- tree
  use {
    "nvim-neo-tree/neo-tree.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    }
  }

  -- PlantUML
  use "javiorfo/nvim-soil"
  use 'javiorfo/nvim-nyctophilia'

  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
