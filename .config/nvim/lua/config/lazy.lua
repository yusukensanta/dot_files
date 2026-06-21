local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone folke/lazy.nvim", "ErrorMsg" },
      { out,                               "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("helpers.keys").set_leader("\\")

local ok, lazy = pcall(require, "lazy")
if not ok then
  return
end

lazy.setup("plugins")

require("helpers.keys").map("n", "<leader>l", lazy.show, "Show lazy.nvim menu")
