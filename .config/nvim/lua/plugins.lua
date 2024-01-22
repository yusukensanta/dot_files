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
  use "nvim-lualine/lualine.nvim" -- Statusline
  use "windwp/nvim-autopairs" -- Autopairs, integrates with both cmp and treesitter
  use "kyazdani42/nvim-web-devicons" -- File icons
  use "ibhagwan/fzf-lua"
  use "nvim-lua/plenary.nvim" -- Common utilities

  -- cmp plugins
  use "hrsh7th/nvim-cmp" -- The completion plugin
  use "hrsh7th/cmp-buffer" -- buffer completions
  use "hrsh7th/cmp-path" -- path completions
  use "hrsh7th/cmp-cmdline" -- cmdline completions
  use "hrsh7th/cmp-nvim-lsp"
  use "hrsh7th/cmp-nvim-lua"
  use "onsails/lspkind-nvim"
  use "mfussenegger/nvim-dap"
  use "jay-babu/mason-nvim-dap.nvim"

  -- snippets
  use "L3MON4D3/LuaSnip" --snippet engine
  use "saadparwaiz1/cmp_luasnip" -- snippet completions

  -- theme
  use "folke/tokyonight.nvim"
  use "crispgm/nvim-tabline"

  -- LSP
  use "neovim/nvim-lspconfig" -- enable LSP
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'
  use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters
  use 'scalameta/nvim-metals'
  -- Formatter
  use "MunifTanjim/prettier.nvim"
  -- Telescope
  use "nvim-telescope/telescope.nvim"

  -- Treesitter
  use {"nvim-treesitter/nvim-treesitter", run = ':TSUpdate'}
  use "nvim-telescope/telescope-file-browser.nvim"
  use "javiorfo/nvim-soil"
  use 'javiorfo/nvim-nyctophilia'

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end

end)


local cmp = require("cmp")
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },

  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    -- { name = "buffer" },
    -- { name = "path" },
  }),
  mapping = cmp.mapping.preset.insert({
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm { select = true },
  }),
  experimental = {
    ghost_text = true,
  },
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

require('nvim-treesitter.configs').setup { highlight = {
    enable = true
  },
  ensure_installed = 'all'
}

metals_config = require("metals").bare_config()
metals_config.settings = {
  showImplicitArguments = true,
  excludedPackages = { 'akka.actor.typed.javadsl', 'com.github.swagger.akka.javadsl' }
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
metals_config.capabilities = capabilities

-- autocmd
autocmd('BufWritePre', {
  pattern = '',
  command = ':%s/\\s\\+$//e'
})
-- Lua
require('lualine').setup {
    options = {
        icons_enabled = true,
        theme = 'tokyonight',
        component_separators = { left = '', right = ''},
        section_separators = { left = '', right = ''},
        disabled_filetypes = {},
        always_divide_middle = true,
        globalstatus = false,
    },
    sections = {
        lualine_a = {'mode'},
        lualine_b = {'branch', 'diff', 'diagnostics'},
        lualine_c = {'filename'},
        lualine_x = {'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {'filename'},
        lualine_x = {'location'},
        lualine_y = {},
        lualine_z = {}
    },
    tabline = {},
    extensions = {}
}

vim.cmd[[colorscheme tokyonight]]
