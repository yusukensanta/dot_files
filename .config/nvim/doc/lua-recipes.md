# Lua Recipes for Neovim

**Target:** Practical examples and patterns
**Neovim Version:** 0.11+
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [Configuration Patterns](#configuration-patterns)
2. [Keymap Recipes](#keymap-recipes)
3. [Autocommand Recipes](#autocommand-recipes)
4. [LSP Customizations](#lsp-customizations)
5. [UI Enhancements](#ui-enhancements)
6. [File Operations](#file-operations)
7. [Buffer and Window Management](#buffer-and-window-management)
8. [Plugin Integration](#plugin-integration)
9. [Utility Functions](#utility-functions)
10. [Advanced Patterns](#advanced-patterns)

---

## Configuration Patterns

### Recipe: Options with Validation

```lua
--- Configure Neovim options with validation
--- @param opts table Options to set
local function configure_options(opts)
  vim.validate({
    opts = { opts, "table" },
  })

  for key, value in pairs(opts) do
    local ok, err = pcall(function()
      vim.opt[key] = value
    end)

    if not ok then
      vim.notify(
        string.format("Failed to set option '%s': %s", key, err),
        vim.log.levels.WARN
      )
    end
  end
end

-- Usage
configure_options({
  number = true,
  relativenumber = true,
  expandtab = true,
  shiftwidth = 2,
})
```

### Recipe: Plugin Configuration Manager

```lua
local M = {}

local config = {}

--- Setup configuration with defaults
--- @param opts table User configuration
function M.setup(opts)
  local defaults = {
    theme = "dark",
    font_size = 14,
    line_wrap = false,
    auto_save = true,
  }

  config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Apply configuration
  M.apply()
end

--- Apply current configuration
function M.apply()
  vim.opt.background = config.theme
  vim.opt.wrap = config.line_wrap

  if config.auto_save then
    -- Setup auto-save
    M._setup_auto_save()
  end
end

--- Get configuration value
--- @param key string Configuration key
--- @return any Configuration value
function M.get(key)
  return config[key]
end

--- Set configuration value
--- @param key string Configuration key
--- @param value any New value
function M.set(key, value)
  config[key] = value
  M.apply()
end

function M._setup_auto_save()
  vim.api.nvim_create_autocmd("FocusLost", {
    callback = function()
      if vim.bo.modified then
        vim.cmd("silent! write")
      end
    end,
  })
end

return M
```

---

## Keymap Recipes

### Recipe: Smart Tab Completion

```lua
--- Smart tab for completion and indentation
local function smart_tab()
  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  elseif vim.snippet.active({ direction = 1 }) then
    return "<cmd>lua vim.snippet.jump(1)<CR>"
  else
    return "<Tab>"
  end
end

vim.keymap.set("i", "<Tab>", smart_tab, { expr = true })

--- Smart shift-tab
local function smart_shift_tab()
  if vim.fn.pumvisible() == 1 then
    return "<C-p>"
  elseif vim.snippet.active({ direction = -1 }) then
    return "<cmd>lua vim.snippet.jump(-1)<CR>"
  else
    return "<S-Tab>"
  end
end

vim.keymap.set("i", "<S-Tab>", smart_shift_tab, { expr = true })
```

### Recipe: Quick Navigation

```lua
--- Jump to next/previous buffer
vim.keymap.set("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })

--- Jump to specific buffer by number
for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, function()
    vim.cmd("buffer " .. i)
  end, { desc = "Go to buffer " .. i })
end

--- Jump to last active buffer
vim.keymap.set("n", "<leader>bl", "<cmd>buffer #<cr>", { desc = "Last buffer" })
```

### Recipe: Better Movement

```lua
--- Move lines up/down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

--- Keep cursor centered when scrolling
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })

--- Keep search results centered
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search (centered)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search (centered)" })

--- Jumplist navigation (centered)
vim.keymap.set("n", "<C-o>", "<C-o>zz", { desc = "Jump back (centered)" })
vim.keymap.set("n", "<C-i>", "<C-i>zz", { desc = "Jump forward (centered)" })
```

### Recipe: Leader Key Groups

```lua
local map = vim.keymap.set

--- File operations
map("n", "<leader>fw", "<cmd>write<cr>", { desc = "Write file" })
map("n", "<leader>fq", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "<leader>fa", "<cmd>wall<cr>", { desc = "Write all" })

--- Window operations
map("n", "<leader>wv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>ws", "<cmd>split<cr>", { desc = "Horizontal split" })
map("n", "<leader>wc", "<cmd>close<cr>", { desc = "Close window" })
map("n", "<leader>wo", "<cmd>only<cr>", { desc = "Only this window" })

--- Buffer operations
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>ba", "<cmd>%bdelete<cr>", { desc = "Delete all buffers" })
map("n", "<leader>bo", "<cmd>%bdelete|edit#|normal `\"<cr>", { desc = "Delete other buffers" })
```

---

## Autocommand Recipes

### Recipe: Filetype-Specific Settings

```lua
--- Configure settings per filetype
local filetype_settings = {
  python = {
    shiftwidth = 4,
    tabstop = 4,
    colorcolumn = "79",
  },
  lua = {
    shiftwidth = 2,
    tabstop = 2,
  },
  go = {
    shiftwidth = 4,
    tabstop = 4,
    expandtab = false,
  },
  markdown = {
    wrap = true,
    spell = true,
    conceallevel = 2,
  },
}

for filetype, settings in pairs(filetype_settings) do
  vim.api.nvim_create_autocmd("FileType", {
    pattern = filetype,
    callback = function()
      for option, value in pairs(settings) do
        vim.opt_local[option] = value
      end
    end,
    desc = string.format("Apply %s settings", filetype),
  })
end
```

### Recipe: Smart Auto-Save

```lua
--- Auto-save with conditions
local auto_save_group = vim.api.nvim_create_augroup("AutoSave", { clear = true })

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  group = auto_save_group,
  callback = function()
    -- Only save if:
    -- 1. Buffer is modified
    -- 2. Buffer has a filename
    -- 3. Buffer is not read-only
    -- 4. Buffer type is normal
    if vim.bo.modified
      and vim.bo.buftype == ""
      and not vim.bo.readonly
      and vim.fn.expand("%") ~= ""
    then
      -- Debounce: wait for user to stop typing
      vim.defer_fn(function()
        if vim.bo.modified then
          vim.cmd("silent! write")
          vim.notify("Auto-saved", vim.log.levels.INFO, { timeout = 500 })
        end
      end, 1000)
    end
  end,
  desc = "Auto-save buffer with debouncing",
})
```

### Recipe: Restore Cursor Position

```lua
--- Remember and restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)

    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
  desc = "Restore cursor position",
})
```

### Recipe: Trim Trailing Whitespace

```lua
--- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    -- Save cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Remove trailing whitespace
    vim.cmd([[%s/\s\+$//e]])

    -- Restore cursor position
    vim.api.nvim_win_set_cursor(0, cursor_pos)
  end,
  desc = "Remove trailing whitespace",
})
```

### Recipe: Highlight Yanked Text

```lua
--- Highlight text on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({
      higroup = "IncSearch",
      timeout = 200,
    })
  end,
  desc = "Highlight yanked text",
})
```

---

## LSP Customizations

### Recipe: Enhanced LSP Setup

```lua
--- Setup LSP with common configurations
local function setup_lsp()
  -- Configure diagnostics
  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      source = "if_many",
    },
    float = {
      border = "rounded",
      source = "always",
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  -- LspAttach autocommand
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      local bufnr = args.buf

      -- Enable completion
      if client.supports_method("textDocument/completion") then
        vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
      end

      -- Enable inlay hints
      if client.supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end

      -- Keymaps
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "gd", vim.lsp.buf.definition, "Go to definition")
      map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
      map("n", "gr", vim.lsp.buf.references, "Show references")
      map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
      map("n", "K", vim.lsp.buf.hover, "Hover documentation")
      map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
      map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
      map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
      map("n", "<leader>f", function()
        vim.lsp.buf.format({ async = true })
      end, "Format buffer")

      -- Diagnostic keymaps
      map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
      map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
      map("n", "<leader>e", vim.diagnostic.open_float, "Show diagnostic")
      map("n", "<leader>q", vim.diagnostic.setloclist, "Diagnostic list")

      -- Toggle inlay hints
      map("n", "<leader>ih", function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
      end, "Toggle inlay hints")
    end,
  })
end

setup_lsp()
```

### Recipe: LSP Progress Indicator

```lua
--- Show LSP progress in statusline or notification
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local value = args.data.result.value

    if value.kind == "end" then
      vim.notify(
        string.format("%s: %s", client.name, value.message or "Complete"),
        vim.log.levels.INFO
      )
    end
  end,
})
```

---

## UI Enhancements

### Recipe: Better Quickfix Window

```lua
--- Auto-open quickfix window
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  callback = function()
    vim.cmd("cwindow")
  end,
})

--- Close quickfix with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true })
  end,
})
```

### Recipe: Floating Window Creator

```lua
--- Create centered floating window
--- @param buf number Buffer number
--- @param width number Window width
--- @param height number Window height
--- @return number Window ID
local function create_float(buf, width, height)
  -- Calculate position
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  return win
end

-- Usage
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "Hello from floating window!",
  "Press q to close",
})

local win = create_float(buf, 50, 10)

vim.keymap.set("n", "q", function()
  vim.api.nvim_win_close(win, true)
end, { buffer = buf })
```

### Recipe: Custom Statusline Component

```lua
--- LSP status component
local function lsp_status()
  local clients = vim.lsp.get_clients({ bufnr = 0 })

  if #clients == 0 then
    return ""
  end

  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end

  return string.format(" LSP[%s]", table.concat(names, ","))
end

--- Git branch component
local function git_branch()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null")
  branch = vim.trim(branch)

  if branch == "" then
    return ""
  end

  return string.format(" %s", branch)
end

-- Use in statusline
vim.opt.statusline = "%f%m " .. "%{luaeval('lsp_status()')} " .. "%{luaeval('git_branch()')} " .. "%=%l,%c %p%%"
```

---

## File Operations

### Recipe: Save All Modified Buffers

```lua
--- Save all modified buffers
local function save_all()
  local saved = 0

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_option(buf, "modified")
      and vim.api.nvim_buf_get_option(buf, "buftype") == ""
    then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("write")
      end)
      saved = saved + 1
    end
  end

  vim.notify(string.format("Saved %d buffer(s)", saved), vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>wa", save_all, { desc = "Save all buffers" })
```

### Recipe: Create Parent Directories on Save

```lua
--- Auto-create parent directories when saving
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local dir = vim.fn.expand("<afile>:p:h")

    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
      vim.notify(string.format("Created directory: %s", dir), vim.log.levels.INFO)
    end
  end,
})
```

### Recipe: Backup Before Save

```lua
--- Create backup before overwriting file
local function backup_file()
  local filepath = vim.fn.expand("%:p")

  if filepath == "" or vim.fn.filereadable(filepath) == 0 then
    return
  end

  local backup_dir = vim.fn.expand("~/.local/share/nvim/backup")
  vim.fn.mkdir(backup_dir, "p")

  local backup_path = string.format(
    "%s/%s.%s.bak",
    backup_dir,
    vim.fn.expand("%:t"),
    os.date("%Y%m%d_%H%M%S")
  )

  vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(filepath), vim.fn.shellescape(backup_path)))
end

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = backup_file,
  desc = "Backup file before save",
})
```

---

## Buffer and Window Management

### Recipe: Smart Buffer Deletion

```lua
--- Delete buffer while preserving window layout
local function smart_buffer_delete()
  local buf = vim.api.nvim_get_current_buf()

  -- Try to switch to previous buffer
  if vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_is_valid(vim.fn.bufnr("#")) then
    vim.cmd("buffer #")
  else
    vim.cmd("bprevious")
  end

  -- Delete the buffer
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = false })
  end
end

vim.keymap.set("n", "<leader>bd", smart_buffer_delete, { desc = "Delete buffer (smart)" })
```

### Recipe: Window Picker

```lua
--- Pick a window to jump to
local function pick_window()
  local windows = vim.api.nvim_tabpage_list_wins(0)

  if #windows == 1 then
    return
  end

  -- Assign labels
  local labels = "abcdefghijklmnopqrstuvwxyz"
  local win_labels = {}

  for i, win in ipairs(windows) do
    local label = string.sub(labels, i, i)
    win_labels[label] = win

    -- Show label in window
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("window_picker"), 0, 0, {
      virt_text = { { string.format("[%s]", label), "Search" } },
      virt_text_pos = "overlay",
    })
  end

  -- Get user input
  local ok, char = pcall(vim.fn.getcharstr)

  -- Clear labels
  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_clear_namespace(buf, vim.api.nvim_create_namespace("window_picker"), 0, -1)
  end

  -- Jump to selected window
  if ok and win_labels[char] then
    vim.api.nvim_set_current_win(win_labels[char])
  end
end

vim.keymap.set("n", "<leader>ww", pick_window, { desc = "Pick window" })
```

---

## Plugin Integration

### Recipe: Telescope Custom Picker

```lua
--- Custom Telescope picker for config files
local function find_config_files()
  local ok, telescope = pcall(require, "telescope.builtin")
  if not ok then
    return
  end

  telescope.find_files({
    prompt_title = "Config Files",
    cwd = vim.fn.stdpath("config"),
    find_command = { "rg", "--files", "--hidden", "--glob", "!.git" },
  })
end

vim.keymap.set("n", "<leader>fc", find_config_files, { desc = "Find config files" })
```

### Recipe: Custom Treesitter Query

```lua
--- Find all function definitions in current buffer
local function list_functions()
  local ok, ts = pcall(require, "vim.treesitter")
  if not ok then
    return
  end

  local parser = ts.get_parser(0)
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for function definitions
  local query = ts.query.parse(parser:lang(), [[
    (function_declaration
      name: (identifier) @name) @func
  ]])

  local functions = {}
  for id, node in query:iter_captures(root, 0) do
    if query.captures[id] == "name" then
      local text = ts.get_node_text(node, 0)
      local row, col = node:start()
      table.insert(functions, {
        name = text,
        lnum = row + 1,
        col = col + 1,
      })
    end
  end

  -- Show in quickfix
  vim.fn.setqflist(functions, "r")
  vim.cmd("copen")
end

vim.keymap.set("n", "<leader>lf", list_functions, { desc = "List functions" })
```

---

## Utility Functions

### Recipe: Copy to System Clipboard

```lua
--- Copy text to system clipboard
--- @param text string Text to copy
local function copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  vim.notify("Copied to clipboard", vim.log.levels.INFO)
end

--- Copy current file path
vim.keymap.set("n", "<leader>yf", function()
  copy_to_clipboard(vim.fn.expand("%:p"))
end, { desc = "Copy file path" })

--- Copy current file name
vim.keymap.set("n", "<leader>yn", function()
  copy_to_clipboard(vim.fn.expand("%:t"))
end, { desc = "Copy file name" })

--- Copy current line
vim.keymap.set("n", "<leader>yl", function()
  local line = vim.api.nvim_get_current_line()
  copy_to_clipboard(line)
end, { desc = "Copy current line" })
```

### Recipe: URL Opener

```lua
--- Open URL under cursor or selected text
local function open_url()
  local url

  -- Check if in visual mode
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
    -- Get selected text
    vim.cmd('noau normal! "vy"')
    url = vim.fn.getreg("v")
  else
    -- Get URL under cursor
    local line = vim.api.nvim_get_current_line()
    url = string.match(line, "https?://[%w-._~:/?#%[%]@!$&'()*+,;=%%]+")
  end

  if url then
    local cmd
    if vim.fn.has("mac") == 1 then
      cmd = "open"
    elseif vim.fn.has("unix") == 1 then
      cmd = "xdg-open"
    else
      cmd = "start"
    end

    vim.fn.system(string.format("%s %s", cmd, vim.fn.shellescape(url)))
    vim.notify("Opening URL: " .. url, vim.log.levels.INFO)
  else
    vim.notify("No URL found", vim.log.levels.WARN)
  end
end

vim.keymap.set({ "n", "v" }, "gx", open_url, { desc = "Open URL" })
```

---

## Advanced Patterns

### Recipe: Plugin Manager for Custom Plugins

```lua
--- Simple plugin loader
local M = {}

M.plugins = {}

--- Register a plugin
--- @param name string Plugin name
--- @param setup function Setup function
function M.register(name, setup)
  M.plugins[name] = {
    name = name,
    setup = setup,
    loaded = false,
  }
end

--- Load a plugin
--- @param name string Plugin name
function M.load(name)
  local plugin = M.plugins[name]

  if not plugin then
    vim.notify("Plugin not found: " .. name, vim.log.levels.ERROR)
    return false
  end

  if plugin.loaded then
    return true
  end

  local ok, err = pcall(plugin.setup)
  if ok then
    plugin.loaded = true
    vim.notify("Loaded plugin: " .. name, vim.log.levels.INFO)
    return true
  else
    vim.notify(string.format("Failed to load %s: %s", name, err), vim.log.levels.ERROR)
    return false
  end
end

--- Load all plugins
function M.load_all()
  for name, _ in pairs(M.plugins) do
    M.load(name)
  end
end

return M
```

### Recipe: Event Bus Pattern

```lua
--- Simple event bus for decoupled communication
local M = {}

M.listeners = {}

--- Subscribe to an event
--- @param event string Event name
--- @param callback function Callback function
--- @return function Unsubscribe function
function M.on(event, callback)
  if not M.listeners[event] then
    M.listeners[event] = {}
  end

  table.insert(M.listeners[event], callback)

  -- Return unsubscribe function
  return function()
    M.off(event, callback)
  end
end

--- Unsubscribe from an event
--- @param event string Event name
--- @param callback function Callback to remove
function M.off(event, callback)
  if not M.listeners[event] then
    return
  end

  for i, cb in ipairs(M.listeners[event]) do
    if cb == callback then
      table.remove(M.listeners[event], i)
      break
    end
  end
end

--- Emit an event
--- @param event string Event name
--- @param ... any Event data
function M.emit(event, ...)
  if not M.listeners[event] then
    return
  end

  for _, callback in ipairs(M.listeners[event]) do
    callback(...)
  end
end

return M

-- Usage:
-- local events = require("events")
-- events.on("file_saved", function(filename)
--   print("Saved:", filename)
-- end)
-- events.emit("file_saved", "init.lua")
```

---

## Complete Example: Custom Plugin

```lua
--- File: lua/myplugin/init.lua
--- A complete example of a custom plugin

local M = {}

-- Private state
local config = {
  enabled = true,
  auto_save = false,
  notify = true,
}

local namespace = vim.api.nvim_create_namespace("myplugin")

--- Setup the plugin
--- @param opts table User configuration
function M.setup(opts)
  -- Merge user config with defaults
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Create commands
  M._create_commands()

  -- Setup autocommands
  if config.auto_save then
    M._setup_auto_save()
  end

  -- Setup keymaps
  M._setup_keymaps()

  vim.notify("MyPlugin loaded", vim.log.levels.INFO)
end

--- Enable the plugin
function M.enable()
  config.enabled = true
  if config.notify then
    vim.notify("MyPlugin enabled", vim.log.levels.INFO)
  end
end

--- Disable the plugin
function M.disable()
  config.enabled = false
  if config.notify then
    vim.notify("MyPlugin disabled", vim.log.levels.INFO)
  end
end

--- Toggle the plugin
function M.toggle()
  if config.enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Main plugin functionality
function M.do_something()
  if not config.enabled then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Do something with the lines...
  vim.notify("Processing " .. #lines .. " lines", vim.log.levels.INFO)
end

--- Private: Create user commands
function M._create_commands()
  vim.api.nvim_create_user_command("MyPluginEnable", M.enable, {
    desc = "Enable MyPlugin",
  })

  vim.api.nvim_create_user_command("MyPluginDisable", M.disable, {
    desc = "Disable MyPlugin",
  })

  vim.api.nvim_create_user_command("MyPluginToggle", M.toggle, {
    desc = "Toggle MyPlugin",
  })
end

--- Private: Setup auto-save
function M._setup_auto_save()
  local group = vim.api.nvim_create_augroup("MyPlugin_AutoSave", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function()
      if config.enabled then
        M.do_something()
      end
    end,
  })
end

--- Private: Setup keymaps
function M._setup_keymaps()
  vim.keymap.set("n", "<leader>mp", M.do_something, {
    desc = "MyPlugin: Do something",
  })

  vim.keymap.set("n", "<leader>mt", M.toggle, {
    desc = "MyPlugin: Toggle",
  })
end

return M

-- Usage in init.lua:
-- require("myplugin").setup({
--   auto_save = true,
--   notify = true,
-- })
```

---

## Testing Your Code

```lua
--- Simple test runner for Lua functions
local function test(name, fn)
  local ok, err = pcall(fn)

  if ok then
    print(string.format("✓ %s", name))
    return true
  else
    print(string.format("✗ %s: %s", name, err))
    return false
  end
end

--- Assert helper
local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format(
      "%s\n  Expected: %s\n  Actual: %s",
      message or "Assertion failed",
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

-- Example tests
test("addition works", function()
  assert_eq(1 + 1, 2, "1 + 1 should equal 2")
end)

test("table merge works", function()
  local result = vim.tbl_extend("force", { a = 1 }, { b = 2 })
  assert_eq(result.a, 1)
  assert_eq(result.b, 2)
end)
```

---

## Debugging Tips

```lua
--- Print variable with inspect
P = function(v)
  print(vim.inspect(v))
  return v
end

--- Reload module (for development)
RELOAD = function(module_name)
  package.loaded[module_name] = nil
  return require(module_name)
end

--- Profile function execution time
local function profile(fn, name)
  local start = vim.loop.hrtime()
  fn()
  local elapsed = (vim.loop.hrtime() - start) / 1e6  -- Convert to ms
  print(string.format("%s took %.2f ms", name or "Function", elapsed))
end

-- Usage:
-- P({ a = 1, b = 2 })  -- Prints table
-- local mod = RELOAD("mymodule")  -- Reloads module
-- profile(expensive_function, "Expensive operation")
```

---

## Next Steps

You now have a comprehensive set of recipes! Continue learning:
- **[Lua Basics](lua-basics.md)** - Lua fundamentals
- **[Module Organization](module-organization.md)** - Structure your config
- **[Neovim Lua API](neovim-lua-api.md)** - API reference

---

## Resources

- **:help lua** - Built-in Lua documentation
- **:help lua-guide** - Lua guide for Neovim
- **:help vim.api** - API reference
- **:help lsp** - LSP documentation

---

*Tutorial Version: 1.0*
*Last Updated: 2025-10-12*
