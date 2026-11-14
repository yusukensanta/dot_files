-- Personal-AI kill switch. Set DOTFILES_NO_PERSONAL_AI=1 (e.g. from
-- ~/.config/zsh/local.d/work.zsh) on machines where personally licensed AI
-- tools (GitHub Copilot, ...) are not allowed. Plugin specs read
-- `enabled` at spec-load time, so the variable must be in the environment
-- before nvim starts.
local M = {}

M.enabled = vim.env.DOTFILES_NO_PERSONAL_AI ~= "1"

return M
