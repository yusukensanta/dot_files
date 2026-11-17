-- General autocmds, the same for every filetype: trailing whitespace,
-- yank highlight, auto-mkdir, cursor restore (CodingExperience) and
-- autoread (AutoRead). Per-language buffer settings (indent, spell, ...)
-- live in after/ftplugin/<filetype>.lua; formatting is conform's
-- (lua/plugins/conform.lua).

local coding_group = vim.api.nvim_create_augroup("CodingExperience", { clear = true })

-- Auto remove trailing whitespace, except in buffers that set
-- vim.b.keep_trailing_whitespace (after/ftplugin/): trailing spaces mean
-- something there, e.g. a hard line break in Markdown or a blank context
-- line in a diff.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = coding_group,
  pattern = "*",
  callback = function()
    if not vim.bo.modifiable or vim.b.keep_trailing_whitespace then
      return
    end

    local save_cursor = vim.fn.getpos(".")
    vim.api.nvim_command([[keeppatterns %s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = coding_group,
  pattern = "*",
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = coding_group,
  pattern = "*",
  callback = function()
    local bufname = vim.fn.expand('<afile>')

    -- URL-scheme buffers (oil://, http://, ...) and non-file buftypes
    -- (terminal, quickfix, help, ...) have no real parent dir to create.
    if bufname:match("^%w+://") then
      return
    end
    if vim.bo.buftype ~= "" then
      return
    end

    vim.fn.mkdir(vim.fn.expand('<afile>:p:h'), 'p')
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = coding_group,
  pattern = "*",
  callback = function()
    if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end,
})

local autoread_group = vim.api.nvim_create_augroup("AutoRead", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = autoread_group,
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= 'c' then  -- Don't check in command-line mode
      vim.cmd("checktime")
    end
  end,
  desc = "Check if file needs to be reloaded from disk"
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = autoread_group,
  pattern = "*",
  callback = function()
    vim.notify("File reloaded: " .. vim.fn.expand("%"), vim.log.levels.WARN)
  end,
  desc = "Notify when file is auto-reloaded"
})
