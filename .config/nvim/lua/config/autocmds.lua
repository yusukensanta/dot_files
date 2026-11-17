-- General autocmds, the same for every filetype: yank highlight,
-- auto-mkdir, cursor restore (CodingExperience) and autoread (AutoRead).
-- Per-language buffer settings (indent, spell, ...) live in
-- after/ftplugin/<filetype>.lua; formatting is conform's
-- (lua/plugins/conform.lua).
--
-- Trailing whitespace is left to the formatters and to Neovim's built-in
-- EditorConfig support (trim_trailing_whitespace in a project's
-- .editorconfig), so saving a file never rewrites lines that weren't
-- touched.

local coding_group = vim.api.nvim_create_augroup("CodingExperience", { clear = true })

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

-- Files git reuses for every commit/rebase/merge/tag message: the same path
-- each time, so the remembered position belongs to an older, unrelated
-- message.
local no_restore = {
  COMMIT_EDITMSG = true,
  MERGE_MSG = true,
  TAG_EDITMSG = true,
  ["git-rebase-todo"] = true,
}

vim.api.nvim_create_autocmd("BufReadPost", {
  group = coding_group,
  pattern = "*",
  callback = function(args)
    if no_restore[vim.fn.fnamemodify(args.file, ":t")] then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
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
