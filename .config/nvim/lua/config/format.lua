-- General Options by Languages
local language_group = vim.api.nvim_create_augroup("LanguageOptions", { clear = true })

-- Resolve biome binary: project-local > global > pinned npx fallback
-- Avoids unpinned `npx --yes` which auto-downloads latest from npm on every call.
local function resolve_biome_cmd()
  local project_biome = vim.fn.findfile("node_modules/.bin/biome", ".;")
  if project_biome ~= "" then
    return { vim.fn.fnamemodify(project_biome, ":p") }
  end
  if vim.fn.executable("biome") == 1 then
    return { "biome" }
  end
  return { "npx", "--yes", "@biomejs/biome@2.3.8" }
end

-- Biome Formatting for TypeScript/JavaScript/JSON
local biome_group = vim.api.nvim_create_augroup("BiomeFormat", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = biome_group,
  pattern = { "*.js", "*.jsx", "*.ts", "*.tsx", "*.json", "*.jsonc" },
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    if not vim.bo[bufnr].modifiable then
      return
    end

    local view = vim.fn.winsaveview()

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")

    local filename = vim.fn.expand("%:p")
    local config_path = vim.fn.expand("~/.config/nvim")
    local cmd = resolve_biome_cmd()
    vim.list_extend(cmd, { "format", "--stdin-file-path", filename, "--config-path", config_path })

    local result = vim.system(cmd, {
      stdin = content,
      text = true,
      timeout = 5000,
    }):wait()

    if result.code == 0 and result.stdout then
      local formatted_lines = vim.split(result.stdout, "\n")

      if formatted_lines[#formatted_lines] == "" and lines[#lines] ~= "" then
        table.remove(formatted_lines)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)
      vim.fn.winrestview(view)
    elseif result.code ~= 0 then
      if result.stderr and result.stderr:match("error") then
        vim.notify("Biome formatting failed:\n" .. result.stderr, vim.log.levels.ERROR)
      end
    end
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = {
    "javascript",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "html",
    "css",
    "scss",
    "less",
    "json",
    "yaml",
    "markdown",
    "lua",
    "vim",
    "xml",
    "ruby",
    "c",
    "cpp",
  },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = {
    "python",
    "java",
    "bash",
    "sh",
    "zsh",
    "rust",
  },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = {
    "go",
    "gomod",
    "gosum",
  },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = "python",
  callback = function()
    vim.opt_local.colorcolumn = "79" -- PEP 8 line length
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = "python",
  callback = function()
    vim.diagnostic.config({
      virtual_text = {
        source = "always",
        format = function(diagnostic)
          -- Show source to distinguish between ty, ruff, and basedpyright
          local source = diagnostic.source or "[N/A]"
          local prefix = ""

          if source == "ty" then
            prefix = "[TYPE] "
          elseif source == "ruff" then
            prefix = "[LINT] "
          elseif source == "basedpyright" then
            prefix = "[COMP] "
          end

          return prefix .. diagnostic.message
        end,
      },
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = language_group,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

local coding_group = vim.api.nvim_create_augroup("CodingExperience", { clear = true })

-- Auto remove trailing whitespace
vim.api.nvim_create_autocmd("BufWritePre", {
  group = coding_group,
  pattern = "*",
  callback = function()
    -- Skip if buffer is not modifiable
    if not vim.bo.modifiable then
      return
    end

    local save_cursor = vim.fn.getpos(".")
    vim.api.nvim_command([[keeppatterns %s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end
})

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = coding_group,
  pattern = "*",
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Auto-create directories when saving files
vim.api.nvim_create_autocmd("BufWritePre", {
  group = coding_group,
  pattern = "*",
  callback = function()
    local bufname = vim.fn.expand('<afile>')

    -- Skip special buffers with URL schemes (oil://, http://, etc.)
    if bufname:match("^%w+://") then
      return
    end

    -- Skip non-file buffers (terminal, quickfix, help, etc.)
    if vim.bo.buftype ~= "" then
      return
    end

    vim.fn.mkdir(vim.fn.expand('<afile>:p:h'), 'p')
  end,
})

-- Jump to last position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
  group = coding_group,
  pattern = "*",
  callback = function()
    if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end,
})
