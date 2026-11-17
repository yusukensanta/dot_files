-- nvim-treesitter (main branch — required for Neovim 0.12+), shared by every
-- language. Parsers come from the language files
-- (lua/plugins/lang/<language>.lua add to `ensure_installed`); the list here
-- is only for filetypes with no language file of their own.
-- NOTE: Requires tree-sitter CLI installed locally:
--   cargo install tree-sitter-cli
-- After switching branches, run:
--   :Lazy update → :TSUninstall all → restart → :TSUpdate → :checkhealth nvim-treesitter
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    -- Not eager: still loads on essentially every real editing session
    -- (any buffer read/created), just skips it for e.g. a bare `nvim`
    -- with no file (dashboard-only) startup.
    event = { "BufReadPost", "BufNewFile" },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = { "diff", "gitcommit", "git_config", "git_rebase", "html", "css", "sql", "regex" },
    },
    config = function(_, opts)
      -- main branch setup() only accepts { install_dir = "..." }
      -- ensure_installed / auto_install are NOT valid options on main branch,
      -- hence the explicit install() below.
      require("nvim-treesitter").setup()

      -- Silently skips if tree-sitter CLI isn't installed yet:
      -- cargo install tree-sitter-cli, then :TSUpdate to populate parsers.
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter.install").install(opts.ensure_installed, { skip_installed = true })
      end

      -- Indentation is left to each filetype's own indent script (and
      -- after/ftplugin/) because the nvim-treesitter main branch moved the
      -- indent module and calling require("nvim-treesitter").indentexpr()
      -- would silently fail, corrupting auto-indent.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true }),
        callback = function(args)
          -- pcall: gracefully skip filetypes without a parser
          pcall(vim.treesitter.start, args.buf)
        end,
      })
      -- No incremental_selection keymaps (<C-space>, <C-s>, <M-space>): <C-space>
      -- is already blink.cmp's show-completion-menu. Neovim 0.12's own built-in
      -- text objects cover the same need in visual mode instead:
      --   v + an  → select around node
      --   v + in  → select inner node
      --   ]n / [n → jump to next/prev node
    end,
  },
}
