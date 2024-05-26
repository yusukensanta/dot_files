-- tab
vim.keymap.set('n', '<C-t>', ":tabnew<CR>", {})
vim.keymap.set('n', '<C-n>', ":tabnext<CR>", {})
vim.keymap.set('n', '<C-p>', ":tabprev<CR>", {})

-- buffer
vim.keymap.set('n', '<leader>n', ":bn<CR>", {})
vim.keymap.set('n', '<leader>p', ":bp<CR>", {})
vim.keymap.set('n', '<leader>x', ":bd<CR>", {})

-- telescope
vim.keymap.set('n', '<leader>ff', ":Telescope find_files<CR>", {})
vim.keymap.set('n', '<leader>fg', ":Telescope live_grep", {})
vim.keymap.set('n', '<leader>fi', ":Telescope git_files", {})
vim.keymap.set('n', '<leader>fb', ":Telescope buffers", {})
vim.keymap.set('n', '<leader>fh', ":Telescope help_tags", {})
vim.keymap.set('n', '<space>fa', ":Telescope file_browser<CR>")
vim.keymap.set('n', '<space>fb', ":Telescope file_browser path=%:p:h select_buffer=true<CR>")

-- neo-tree
vim.keymap.set('n', '<leader>t', ":Neotree toggle<CR>", {})
vim.keymap.set('n', '<leader>tf', ":Neotree focus<CR>", {})
vim.keymap.set('n', '<leader>gs', ":Neotree git_status<CR>", {})
