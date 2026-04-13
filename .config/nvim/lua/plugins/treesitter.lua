-- nvim-treesitter (main branch — required for Neovim 0.12+)
-- NOTE: Requires tree-sitter CLI installed locally:
--   cargo install tree-sitter-cli
-- After switching branches, run:
--   :Lazy update → :TSUninstall all → restart → :TSUpdate → :checkhealth nvim-treesitter
return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = ":TSUpdate",
		config = function()
			-- main branch setup() only accepts { install_dir = "..." }
			-- ensure_installed / auto_install are NOT valid options on main branch (silently ignored)
			require("nvim-treesitter").setup()

			-- Install missing parsers on startup (replaces the old ensure_installed option).
			-- Guarded: silently skips if tree-sitter CLI is not installed yet.
			-- To install the CLI: cargo install tree-sitter-cli
			-- After installing the CLI, run :TSUpdate to populate parsers.
			if vim.fn.executable("tree-sitter") == 1 then
				require("nvim-treesitter.install").install({
					"c",
					"lua",
					"python",
					"rust",
					"go",
					"ruby",
					"scala",
					"toml",
					"yaml",
					"markdown",
					"bash",
				}, { skip_installed = true })
			end

			-- Enable treesitter highlighting per filetype.
			-- Indentation is intentionally left to options.lua (smartindent + autoindent)
			-- because the nvim-treesitter main branch moved the indent module and calling
			-- require("nvim-treesitter").indentexpr() would silently fail, corrupting auto-indent.
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true }),
				callback = function(args)
					-- pcall: gracefully skip filetypes without a parser
					pcall(vim.treesitter.start, args.buf)
				end,
			})

			-- Neovim 0.12 ships built-in treesitter text objects (v_an, v_in, v_]n, v_[n).
			-- The old incremental_selection keymaps (<C-space>, <C-s>, <M-space>) are removed
			-- because <C-space> is already used by blink.cmp (show completion menu).
			-- Use the built-in text objects in visual mode instead:
			--   v + an  → select around node
			--   v + in  → select inner node
			--   ]n / [n → jump to next/prev node
		end,
	},
}
