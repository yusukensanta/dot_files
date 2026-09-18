# Neovim Lua API Reference

**Target:** Learning Neovim-specific Lua APIs
**Neovim Version:** 0.11+
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [Introduction](#introduction)
2. [vim.api - Core API](#vimapi---core-api)
3. [vim.fn - Vim Functions](#vimfn---vim-functions)
4. [vim.opt - Options](#vimopt---options)
5. [vim.keymap - Keymaps](#vimkeymap---keymaps)
6. [vim.diagnostic - Diagnostics](#vimdiagnostic---diagnostics)
7. [vim.lsp - LSP Client](#vimlsp---lsp-client)
8. [vim.treesitter - Treesitter](#vimtreesitter---treesitter)
9. [vim.fs - File System](#vimfs---file-system)
10. [vim.loop / vim.uv - Async I/O](#vimloop--vimuv---async-io)
11. [Utility APIs](#utility-apis)

---

## Introduction

Neovim provides several Lua API namespaces:

| Namespace | Purpose | Example |
|-----------|---------|---------|
| `vim.api` | Core Neovim API (from C) | `vim.api.nvim_buf_set_lines()` |
| `vim.fn` | Vim functions | `vim.fn.expand("%:p")` |
| `vim.cmd` | Execute Ex commands | `vim.cmd("edit file.txt")` |
| `vim.opt` | Option management | `vim.opt.number = true` |
| `vim.keymap` | Keymap management | `vim.keymap.set("n", ...)` |
| `vim.lsp` | LSP client | `vim.lsp.buf.hover()` |
| `vim.diagnostic` | Diagnostics | `vim.diagnostic.open_float()` |
| `vim.treesitter` | Treesitter | `vim.treesitter.get_parser()` |
| `vim.fs` | File system operations | `vim.fs.dirname(path)` |
| `vim.loop` / `vim.uv` | Event loop (libuv) | `vim.uv.fs_stat(path)` |

---

## vim.api - Core API

The `vim.api` namespace provides low-level Neovim APIs.

### Buffer Operations

```lua
-- Get current buffer number
local bufnr = vim.api.nvim_get_current_buf()

-- Create a new buffer
local buf = vim.api.nvim_create_buf(false, true)  -- (listed, scratch)

-- Get buffer lines
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

-- Set buffer lines
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "Line 1",
  "Line 2",
  "Line 3"
})

-- Get buffer name
local name = vim.api.nvim_buf_get_name(bufnr)

-- Set buffer name
vim.api.nvim_buf_set_name(bufnr, "new_name.txt")

-- Delete buffer
vim.api.nvim_buf_delete(bufnr, { force = false })

-- Check if buffer is valid
local valid = vim.api.nvim_buf_is_valid(bufnr)

-- Get/set buffer variable
vim.api.nvim_buf_set_var(bufnr, "my_var", "value")
local value = vim.api.nvim_buf_get_var(bufnr, "my_var")

-- Get/set buffer option
vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")

-- Get buffer info
local info = vim.api.nvim_get_current_buf()
```

### Window Operations

```lua
-- Get current window
local win = vim.api.nvim_get_current_win()

-- Get all windows
local windows = vim.api.nvim_list_wins()

-- Get window buffer
local bufnr = vim.api.nvim_win_get_buf(win)

-- Set window buffer
vim.api.nvim_win_set_buf(win, bufnr)

-- Get cursor position
local cursor = vim.api.nvim_win_get_cursor(win)
local row, col = cursor[1], cursor[2]

-- Set cursor position (1-indexed row, 0-indexed col)
vim.api.nvim_win_set_cursor(win, { 10, 5 })

-- Get window dimensions
local width = vim.api.nvim_win_get_width(win)
local height = vim.api.nvim_win_get_height(win)

-- Set window dimensions
vim.api.nvim_win_set_width(win, 80)
vim.api.nvim_win_set_height(win, 24)

-- Close window
vim.api.nvim_win_close(win, false)  -- force

-- Create floating window
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, true, {
  relative = "editor",
  width = 50,
  height = 10,
  row = 5,
  col = 10,
  style = "minimal",
  border = "rounded",
})
```

### Autocommands

```lua
-- Create autocommand
local autocmd_id = vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.lua",
  callback = function(args)
    print("Saving Lua file:", args.file)
    -- args.buf - buffer number
    -- args.file - file name
    -- args.match - matched pattern
  end,
  desc = "Print message before saving Lua files",
})

-- Create autocommand group
local group = vim.api.nvim_create_augroup("MyGroup", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  pattern = "*.py",
  callback = function()
    vim.opt_local.expandtab = true
  end,
})

-- Delete autocommand
vim.api.nvim_del_autocmd(autocmd_id)

-- Clear autocommand group
vim.api.nvim_clear_autocmds({ group = "MyGroup" })
```

### User Commands

```lua
-- Create user command
vim.api.nvim_create_user_command("Hello", function(opts)
  print("Hello, " .. (opts.args or "World"))
end, {
  nargs = "?",  -- Optional argument
  desc = "Say hello",
})

-- Usage: :Hello
-- Usage: :Hello Neovim

-- Command with completion
vim.api.nvim_create_user_command("EditConfig", function(opts)
  vim.cmd.edit(opts.fargs[1])
end, {
  nargs = 1,
  complete = "file",
  desc = "Edit config file",
})

-- Delete user command
vim.api.nvim_del_user_command("Hello")
```

### Variables

```lua
-- Global variables (g:)
vim.api.nvim_set_var("my_global", "value")
local value = vim.api.nvim_get_var("my_global")

-- Buffer variables (b:)
vim.api.nvim_buf_set_var(0, "my_buffer_var", "value")
local value = vim.api.nvim_buf_get_var(0, "my_buffer_var")

-- Window variables (w:)
vim.api.nvim_win_set_var(0, "my_window_var", "value")
local value = vim.api.nvim_win_get_var(0, "my_window_var")

-- Tabpage variables (t:)
vim.api.nvim_tabpage_set_var(0, "my_tab_var", "value")
local value = vim.api.nvim_tabpage_get_var(0, "my_tab_var")

-- Vim variables (v:)
local count = vim.api.nvim_get_vvar("count")
```

---

## vim.fn - Vim Functions

Access any Vim function through `vim.fn`:

```lua
-- File operations
local home = vim.fn.expand("~")
local cwd = vim.fn.getcwd()
local file_exists = vim.fn.filereadable("file.txt") == 1
local dir_exists = vim.fn.isdirectory("dir") == 1

-- String operations
local input = vim.fn.input("Enter name: ")
local confirmed = vim.fn.confirm("Delete file?", "&Yes\n&No", 2)

-- Cursor and position
local line = vim.fn.line(".")
local col = vim.fn.col(".")
local visual_start = vim.fn.line("'<")
local visual_end = vim.fn.line("'>")

-- Registers
local content = vim.fn.getreg('"')  -- Get default register
vim.fn.setreg('"', "new content")   -- Set register

-- Search and replace
local match_pos = vim.fn.match("hello world", "world")
local substituted = vim.fn.substitute("hello", "e", "a", "g")

-- Buffer and window
local bufnr = vim.fn.bufnr("%")
local bufname = vim.fn.bufname(bufnr)
local winnr = vim.fn.winnr()

-- System
local output = vim.fn.system("ls -la")
local exit_code = vim.v.shell_error

-- Time and date
local now = vim.fn.localtime()
local formatted = vim.fn.strftime("%Y-%m-%d %H:%M:%S")

-- Lists (arrays)
local idx = vim.fn.index({ "a", "b", "c" }, "b")  -- 1
local max = vim.fn.max({ 1, 5, 3, 9 })             -- 9
local min = vim.fn.min({ 1, 5, 3, 9 })             -- 1

-- Mode
local mode = vim.fn.mode()  -- "n", "i", "v", etc.
```

---

## vim.opt - Options

The `vim.opt` API provides a Lua-friendly way to set options:

```lua
-- Set option
vim.opt.number = true
vim.opt.relativenumber = true

-- Get option value
local value = vim.opt.number:get()  -- true

-- Append to option
vim.opt.wildignore:append("*.o")
vim.opt.path:append("/usr/include")

-- Prepend to option
vim.opt.path:prepend("./include")

-- Remove from option
vim.opt.wildignore:remove("*.o")

-- List-like options
vim.opt.shortmess:append("c")
vim.opt.shortmess:remove("F")

-- Dictionary-like options
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
}

-- Alternative: vim.o (simple values only)
vim.o.number = true

-- Buffer-local options
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = true

-- Window-local options
vim.opt_local.wrap = true

-- Global options
vim.opt_global.encoding = "utf-8"

-- Shorthand: vim.bo (buffer), vim.wo (window), vim.go (global)
vim.bo.filetype = "lua"
vim.wo.wrap = false
vim.go.encoding = "utf-8"
```

### Option Scopes

```lua
-- Global-local options
vim.opt.shiftwidth = 2              -- Sets global and local
vim.opt_global.shiftwidth = 2       -- Sets only global
vim.opt_local.shiftwidth = 2        -- Sets only local

-- Check option value
if vim.opt.number:get() then
  print("Line numbers enabled")
end

-- Get all option info
local info = vim.api.nvim_get_option_info2("number", {})
```

---

## vim.keymap - Keymaps

Modern keymap API (replaces `vim.api.nvim_set_keymap`):

```lua
-- Basic keymap
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>")

-- With options
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", {
  silent = true,
  noremap = true,
  desc = "Save file",
})

-- Multiple modes
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', {
  desc = "Yank to system clipboard",
})

-- Lua function as RHS
vim.keymap.set("n", "<leader>d", function()
  vim.diagnostic.open_float()
end, { desc = "Show diagnostic" })

-- Buffer-local keymap
vim.keymap.set("n", "K", vim.lsp.buf.hover, {
  buffer = 0,  -- Current buffer
  desc = "LSP hover",
})

-- Expression mapping
vim.keymap.set("i", "<Tab>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  else
    return "<Tab>"
  end
end, { expr = true })

-- Delete keymap
vim.keymap.del("n", "<leader>ff")

-- Get keymap
local keymaps = vim.keymap.get("n")  -- All normal mode keymaps
```

---

## vim.diagnostic - Diagnostics

Manage diagnostics (errors, warnings, info):

```lua
-- Configure diagnostics globally
vim.diagnostic.config({
  virtual_text = {
    severity = vim.diagnostic.severity.ERROR,  -- Only errors
    source = "always",
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

-- Open diagnostic floating window
vim.diagnostic.open_float(nil, {
  scope = "line",  -- or "buffer", "cursor"
})

-- Navigate diagnostics
vim.diagnostic.goto_next()
vim.diagnostic.goto_prev()
vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })

-- Get diagnostics
local diagnostics = vim.diagnostic.get(0)  -- Current buffer
for _, diag in ipairs(diagnostics) do
  print(diag.message, diag.severity, diag.lnum)
end

-- Set diagnostics
vim.diagnostic.set(namespace_id, bufnr, {
  {
    lnum = 10,
    col = 5,
    message = "Unused variable",
    severity = vim.diagnostic.severity.WARN,
    source = "lua_ls",
  },
})

-- Clear diagnostics
vim.diagnostic.reset(namespace_id, bufnr)

-- Show diagnostics in quickfix or loclist
vim.diagnostic.setqflist()
vim.diagnostic.setloclist()

-- Enable/disable diagnostics
vim.diagnostic.enable()
vim.diagnostic.disable()
vim.diagnostic.enable(not vim.diagnostic.is_enabled())  -- Toggle

-- Severity levels
vim.diagnostic.severity.ERROR  -- 1
vim.diagnostic.severity.WARN   -- 2
vim.diagnostic.severity.INFO   -- 3
vim.diagnostic.severity.HINT   -- 4
```

---

## vim.lsp - LSP Client

Built-in LSP client API:

### Setup and Configuration

```lua
-- Neovim 0.11+ setup pattern
vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  root_markers = { ".git", ".luarc.json" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
    },
  },
})

vim.lsp.enable("lua_ls")

-- LspAttach autocommand (recommended)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    -- Set keymaps
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
      buffer = bufnr,
      desc = "Go to definition",
    })

    -- Enable inlay hints
    if client.supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end

    -- Format on save
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })
    end
  end,
})
```

### LSP Buffer Functions

```lua
-- Navigation
vim.lsp.buf.definition()
vim.lsp.buf.declaration()
vim.lsp.buf.type_definition()
vim.lsp.buf.implementation()
vim.lsp.buf.references()

-- Information
vim.lsp.buf.hover()
vim.lsp.buf.signature_help()

-- Code actions
vim.lsp.buf.code_action()
vim.lsp.buf.rename()

-- Formatting
vim.lsp.buf.format({
  async = false,
  bufnr = bufnr,
  timeout_ms = 2000,
  filter = function(client)
    return client.name ~= "tsserver"
  end,
})

-- Document symbols
vim.lsp.buf.document_symbol()
vim.lsp.buf.workspace_symbol("query")

-- Workspace operations
vim.lsp.buf.add_workspace_folder()
vim.lsp.buf.remove_workspace_folder()
vim.lsp.buf.list_workspace_folders()
```

### LSP Client Management

```lua
-- Get active clients
local clients = vim.lsp.get_clients({ bufnr = 0 })

for _, client in ipairs(clients) do
  print(client.name, client.id)
end

-- Get client by ID
local client = vim.lsp.get_client_by_id(client_id)

-- Stop client
vim.lsp.stop_client(client_id)

-- Check if client supports method
if client.supports_method("textDocument/formatting") then
  -- format...
end
```

### Inlay Hints (0.10+)

```lua
-- Enable inlay hints
vim.lsp.inlay_hint.enable(true, { bufnr = 0 })

-- Disable inlay hints
vim.lsp.inlay_hint.enable(false, { bufnr = 0 })

-- Toggle inlay hints
vim.lsp.inlay_hint.enable(
  not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }),
  { bufnr = 0 }
)
```

### Completion (0.11+)

```lua
-- Enable built-in completion
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)

    if client.supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, {
        autotrigger = true,
      })
    end
  end,
})
```

---

## vim.treesitter - Treesitter

Tree-sitter integration:

```lua
-- Get parser for buffer
local parser = vim.treesitter.get_parser(0, "lua")

-- Parse and get tree
local tree = parser:parse()[1]
local root = tree:root()

-- Query
local query = vim.treesitter.query.parse("lua", [[
  (function_declaration
    name: (identifier) @function.name)
]])

for id, node in query:iter_captures(root, 0) do
  local name = vim.treesitter.get_node_text(node, 0)
  print("Function:", name)
end

-- Get node at cursor
local node = vim.treesitter.get_node()

-- Get node text
local text = vim.treesitter.get_node_text(node, 0)

-- Folding expression (0.11+)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- Check if treesitter is active
local active = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
```

---

## vim.fs - File System

File system utilities (0.11+):

```lua
-- Get file/directory name
local dir = vim.fs.dirname("/path/to/file.txt")  -- "/path/to"
local base = vim.fs.basename("/path/to/file.txt")  -- "file.txt"

-- Normalize path
local normalized = vim.fs.normalize("~/.config/nvim")

-- Get absolute path
local abs = vim.fs.abspath("./file.txt")

-- Get relative path
local rel = vim.fs.relpath("/home/user/file.txt", "/home/user")  -- "file.txt"

-- Find files/directories
local found = vim.fs.find({ "init.lua", ".git" }, {
  upward = true,
  path = vim.fn.getcwd(),
  type = "file",
})

-- Find root directory
local root = vim.fs.root(0, { ".git", "package.json" })

-- Remove file/directory (0.11+)
vim.fs.rm("/path/to/file", { recursive = true, force = true })
```

---

## vim.loop / vim.uv - Async I/O

Event loop (libuv) for async operations:

```lua
-- Note: vim.loop is deprecated, use vim.uv instead (same API)

-- Check if file exists
local stat = vim.uv.fs_stat("/path/to/file")
if stat then
  print("File size:", stat.size)
  print("Modified:", stat.mtime.sec)
end

-- Read file asynchronously
vim.uv.fs_open("/path/to/file", "r", 438, function(err, fd)
  if err then
    print("Error:", err)
    return
  end

  vim.uv.fs_fstat(fd, function(err, stat)
    vim.uv.fs_read(fd, stat.size, 0, function(err, data)
      print("File contents:", data)
      vim.uv.fs_close(fd)
    end)
  end)
end)

-- Create directory
vim.uv.fs_mkdir("/path/to/dir", 493)  -- 0755 in octal

-- Timer
local timer = vim.uv.new_timer()
timer:start(1000, 1000, function()  -- delay, repeat
  print("Timer fired!")
end)

-- Stop timer
timer:stop()
```

---

## Utility APIs

### vim.schedule

Schedule callback on main event loop:

```lua
vim.schedule(function()
  -- This runs on the main loop
  vim.notify("Scheduled message")
end)
```

### vim.defer_fn

Execute function after delay:

```lua
vim.defer_fn(function()
  print("Executed after 1 second")
end, 1000)
```

### vim.notify

User notifications:

```lua
vim.notify("Hello!", vim.log.levels.INFO)
vim.notify("Warning!", vim.log.levels.WARN)
vim.notify("Error!", vim.log.levels.ERROR)
```

### vim.inspect

Pretty-print Lua tables:

```lua
local table = { a = 1, b = { c = 2 } }
print(vim.inspect(table))
-- {
--   a = 1,
--   b = {
--     c = 2
--   }
-- }
```

### vim.split

Split strings:

```lua
local parts = vim.split("a,b,c", ",")  -- { "a", "b", "c" }
local lines = vim.split("line1\nline2", "\n")
```

### vim.trim

Trim whitespace:

```lua
local trimmed = vim.trim("  hello  ")  -- "hello"
```

### vim.tbl_* - Table Utilities

```lua
-- Extend table
local merged = vim.tbl_extend("force", { a = 1 }, { b = 2 })  -- { a = 1, b = 2 }

-- Deep extend
local deep = vim.tbl_deep_extend("force", { a = { b = 1 } }, { a = { c = 2 } })
-- { a = { b = 1, c = 2 } }

-- Filter table
local evens = vim.tbl_filter(function(v) return v % 2 == 0 end, { 1, 2, 3, 4 })
-- { 2, 4 }

-- Map table
local doubled = vim.tbl_map(function(v) return v * 2 end, { 1, 2, 3 })
-- { 2, 4, 6 }

-- Check if table is empty
local empty = vim.tbl_isempty({})  -- true

-- Count keys
local count = vim.tbl_count({ a = 1, b = 2 })  -- 2

-- Check if value exists
local contains = vim.tbl_contains({ 1, 2, 3 }, 2)  -- true

-- Get table keys
local keys = vim.tbl_keys({ a = 1, b = 2 })  -- { "a", "b" }

-- Get table values
local values = vim.tbl_values({ a = 1, b = 2 })  -- { 1, 2 }
```

### vim.validate

Validate function arguments:

```lua
function my_function(name, age, opts)
  vim.validate({
    name = { name, "string" },
    age = { age, "number" },
    opts = { opts, "table", true },  -- Optional (true)
  })

  -- Function body...
end

-- Raises error if validation fails
my_function("Alice", 30, { verbose = true })  -- OK
my_function(123, 30)  -- ERROR: name must be string
```

### vim.json

JSON encoding/decoding:

```lua
-- Encode
local json = vim.json.encode({ name = "Neovim", version = 0.11 })

-- Decode
local obj = vim.json.decode('{"name":"Neovim"}')
```

### vim.base64

Base64 encoding/decoding:

```lua
local encoded = vim.base64.encode("Hello, Neovim!")
local decoded = vim.base64.decode(encoded)
```

---

## Practical Examples

### Example 1: Safe Module Loading

```lua
local function safe_require(module, opts)
  opts = opts or {}
  local ok, result = pcall(require, module)

  if not ok then
    if opts.silent then
      return nil
    else
      vim.notify(
        string.format("Failed to load module '%s': %s", module, result),
        vim.log.levels.ERROR
      )
      return nil
    end
  end

  return result
end

-- Usage
local telescope = safe_require("telescope")
if telescope then
  telescope.setup()
end
```

### Example 2: Custom Command with Completion

```lua
vim.api.nvim_create_user_command("Config", function(opts)
  local config_files = {
    options = "~/.config/nvim/lua/config/options.lua",
    plugins = "~/.config/nvim/lua/plugins/init.lua",
    keymaps = "~/.config/nvim/lua/config/keymaps.lua",
  }

  local file = config_files[opts.fargs[1]]
  if file then
    vim.cmd.edit(vim.fn.expand(file))
  else
    vim.notify("Invalid config file", vim.log.levels.ERROR)
  end
end, {
  nargs = 1,
  complete = function()
    return { "options", "plugins", "keymaps" }
  end,
  desc = "Edit configuration file",
})

-- Usage: :Config options
```

### Example 3: Auto-save on Focus Lost

```lua
local function auto_save()
  local group = vim.api.nvim_create_augroup("AutoSave", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
    group = group,
    pattern = "*",
    callback = function()
      if vim.bo.modified and vim.bo.buftype == "" then
        vim.cmd("silent! write")
      end
    end,
    desc = "Auto-save on focus lost",
  })
end

auto_save()
```

---

## API Reference Quick Links

- **Full API documentation:** `:help api`
- **Lua guide:** `:help lua-guide`
- **LSP:** `:help lsp`
- **Diagnostic:** `:help diagnostic`
- **Treesitter:** `:help treesitter`

---

## Next Steps

- **[Lua Basics](lua-basics.md)** - Lua fundamentals
- **[Module Organization](module-organization.md)** - Structure your config
- **[Lua Recipes](lua-recipes.md)** - Practical examples

---

*Tutorial Version: 1.0*
*Last Updated: 2025-10-12*
