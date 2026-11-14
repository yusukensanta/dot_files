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

require("helpers.keys").set_leader(",", "\\")

local ok, lazy = pcall(require, "lazy")
if not ok then
  vim.api.nvim_echo({ { "Failed to load lazy.nvim: " .. tostring(lazy), "ErrorMsg" } }, true, { err = true })
  return
end

-- `local.plugins` (lua/local/plugins/*.lua) is gitignored, host-specific,
-- and not synced — drop specs there to add or override (e.g. enabled = false)
-- plugins on one machine. lazy merges specs by plugin name. Imported only
-- when the directory exists: lazy raises "No specs found" for an empty or
-- missing module, which is the normal state on a fresh machine.
local spec = { { import = "plugins" } }
if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/local/plugins") then
  table.insert(spec, { import = "local.plugins" })
end

lazy.setup(spec, {
  rocks = { enabled = false },
})

require("helpers.keys").map("n", "<leader>l", lazy.show, "Show lazy.nvim menu")
