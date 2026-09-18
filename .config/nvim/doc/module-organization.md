# Module Organization in Neovim

**Target:** Organizing Neovim configuration with Lua modules
**Neovim Version:** 0.11+
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [Introduction](#introduction)
2. [Directory Structure](#directory-structure)
3. [Module Loading](#module-loading)
4. [Configuration Patterns](#configuration-patterns)
5. [Plugin Organization](#plugin-organization)
6. [Helper Modules](#helper-modules)
7. [Autocommands and Keymaps](#autocommands-and-keymaps)
8. [Best Practices](#best-practices)

---

## Introduction

### Why Organize Configuration?

Well-organized Neovim configuration:
- **Maintainable:** Easy to find and update settings
- **Modular:** Each component is self-contained
- **Reusable:** Share modules across projects
- **Performant:** Lazy-load modules when needed
- **Testable:** Easier to debug and test

### Configuration Entry Points

Neovim looks for configuration in these locations (in order):

```
~/.config/nvim/init.lua           # Main entry point (Lua)
~/.config/nvim/init.vim           # Main entry point (VimScript)

# Cannot use both! Choose one.
```

---

## Directory Structure

### Recommended Structure

```
~/.config/nvim/
├── init.lua                      # Main entry point
├── lua/                          # Lua modules directory
│   ├── config/                   # Core configuration
│   │   ├── init.lua              # Configuration loader
│   │   ├── options.lua           # Vim options
│   │   ├── keymaps.lua           # Global keymaps
│   │   ├── autocmds.lua          # Autocommands
│   │   └── lazy.lua              # Plugin manager setup
│   ├── plugins/                  # Plugin specifications
│   │   ├── init.lua              # Plugin loader (optional)
│   │   ├── lsp.lua               # LSP configuration
│   │   ├── treesitter.lua        # Treesitter config
│   │   ├── telescope.lua         # Telescope config
│   │   └── ...                   # More plugins
│   └── helpers/                  # Helper utilities
│       ├── keys.lua              # Keymap helpers
│       ├── utils.lua             # General utilities
│       └── lsp.lua               # LSP utilities
├── after/                        # Run after plugins load
│   ├── plugin/                   # Additional plugin configs
│   └── ftplugin/                 # Filetype-specific configs
│       ├── lua.lua               # Lua file settings
│       ├── python.lua            # Python file settings
│       └── ...
├── plugin/                       # Auto-loaded plugins
├── doc/                          # Documentation
└── colors/                       # Custom colorschemes (optional)
```

### Your Current Structure

Based on your config:

```
~/.config/nvim/
├── init.lua                      # ✓ Main entry
├── lua/
│   ├── config/
│   │   ├── lazy.lua              # ✓ Plugin manager
│   │   ├── options.lua           # ✓ Options + keymaps
│   │   └── format.lua            # ✓ Filetype configs
│   ├── plugins/                  # ✓ Plugin specs
│   │   ├── lsp.lua
│   │   ├── treesitter.lua
│   │   ├── telescope.lua
│   │   └── ...
│   └── helpers/
│       └── keys.lua              # ✓ Keymap helper
└── doc/                          # ✓ Documentation
```

**This is already well-organized!** Minor improvements suggested below.

---

## Module Loading

### How require() Works

```lua
-- Neovim searches for modules in 'runtimepath'
-- Default search paths:
--   ~/.config/nvim/lua/
--   /usr/share/nvim/runtime/lua/
--   [plugin paths]/lua/

-- Example: require("config.options")
-- Searches for:
--   ~/.config/nvim/lua/config/options.lua
--   ~/.config/nvim/lua/config/options/init.lua
```

### Basic Module Loading

```lua
-- Load a module
local module = require("mymodule")

-- Use module functions
module.some_function()

-- Load submodule
local utils = require("mymodule.utils")
```

### Protected Loading (Recommended)

```lua
-- Safely load optional modules
local ok, module = pcall(require, "optional_module")
if not ok then
  vim.notify("Module not found: optional_module", vim.log.levels.WARN)
  return
end

-- Use module...
module.setup()
```

### Module Caching

```lua
-- Modules are cached after first load
local mod1 = require("mymodule")  -- Loads and caches
local mod2 = require("mymodule")  -- Returns cached version
-- mod1 == mod2 (same table)

-- Reload a module (for development)
package.loaded["mymodule"] = nil  -- Clear cache
local fresh = require("mymodule")  -- Loads again
```

---

## Configuration Patterns

### Pattern 1: Simple Entry Point

**File: `init.lua`**

```lua
-- Enable faster module loading
vim.loader.enable()

-- Load configurations in order
require("config.options")    -- Vim options
require("config.keymaps")    -- Global keymaps
require("config.autocmds")   -- Autocommands
require("config.lazy")       -- Plugin manager (loads plugins)
```

**Pros:** Simple, clear loading order
**Cons:** All modules load on startup

---

### Pattern 2: Conditional Loading

**File: `init.lua`**

```lua
vim.loader.enable()

-- Load core config
require("config.options")

-- Conditionally load plugin manager
if vim.fn.argc() == 0 then
  -- Only load plugins if no file arguments
  require("config.lazy")
else
  -- Fast startup when opening files directly
  vim.defer_fn(function()
    require("config.lazy")
  end, 10)
end

-- Load rest of config
require("config.keymaps")
require("config.autocmds")
```

**Pros:** Faster startup for quick edits
**Cons:** More complex

---

### Pattern 3: Modular Config Loader

**File: `lua/config/init.lua`**

```lua
local M = {}

-- Configuration modules to load
local modules = {
  "config.options",
  "config.keymaps",
  "config.autocmds",
  "config.lazy",
}

-- Load all modules with error handling
function M.load()
  for _, module_name in ipairs(modules) do
    local ok, err = pcall(require, module_name)
    if not ok then
      vim.notify(
        string.format("Error loading %s:\n%s", module_name, err),
        vim.log.levels.ERROR
      )
    end
  end
end

return M
```

**File: `init.lua`**

```lua
vim.loader.enable()
require("config").load()
```

**Pros:** Centralized loading, better error handling
**Cons:** Slightly more complex

---

### Pattern 4: Lazy Configuration (Your Current Pattern)

**File: `init.lua`**

```lua
vim.loader.enable()
require("config.lazy")
require("config.options")
require("config.format")
```

**This is excellent!** You load the plugin manager first, which handles lazy-loading of plugins.

---

## Plugin Organization

### Pattern 1: Single Plugin File (Small Configs)

**File: `lua/plugins/init.lua`**

```lua
return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require("lualine").setup()
    end,
  },

  -- More plugins...
}
```

**Pros:** Simple for small configs
**Cons:** Gets unwieldy with many plugins

---

### Pattern 2: Plugin Per File (Your Current Pattern)

**Structure:**
```
lua/plugins/
├── lsp.lua              # LSP + mason
├── treesitter.lua       # Treesitter
├── telescope.lua        # Telescope
├── cmp.lua              # Completion
├── git_ops.lua          # Git plugins
└── ...
```

**File: `lua/plugins/telescope.lua`**

```lua
return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        -- config...
      })
    end,
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    },
  },
}
```

**With lazy.nvim, all files in `lua/plugins/` are automatically loaded!**

**Pros:**
- Organized by functionality
- Easy to find plugin configs
- Automatic loading with lazy.nvim

**Cons:**
- None! This is the recommended pattern.

---

### Pattern 3: Grouped Plugins

**File: `lua/plugins/editor.lua`**

```lua
return {
  -- Fuzzy finder
  { "nvim-telescope/telescope.nvim", --[[ config ]] },

  -- File explorer
  { "stevearc/oil.nvim", --[[ config ]] },

  -- Comment plugin
  { "numToStr/Comment.nvim", --[[ config ]] },

  -- Surround
  { "kylechui/nvim-surround", --[[ config ]] },
}
```

**File: `lua/plugins/coding.lua`**

```lua
return {
  { "hrsh7th/nvim-cmp", --[[ config ]] },
  { "nvim-treesitter/nvim-treesitter", --[[ config ]] },
  -- More coding-related plugins...
}
```

**Pros:** Logical grouping
**Cons:** Subjective boundaries between groups

---

### Pattern 4: Configuration Extraction

For complex plugin configs, extract logic to separate modules:

**File: `lua/plugins/lsp.lua`**

```lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason.nvim", "mason-lspconfig.nvim" },
    config = function()
      -- Use helper module
      require("helpers.lsp").setup()
    end,
  },
}
```

**File: `lua/helpers/lsp.lua`**

```lua
local M = {}

function M.setup()
  -- Complex LSP setup logic here
  local servers = { "lua_ls", "pyright", "gopls" }

  for _, server in ipairs(servers) do
    require("lspconfig")[server].setup({
      -- server config
    })
  end
end

return M
```

**Pros:** Cleaner plugin files, reusable logic
**Cons:** More files to manage

---

## Helper Modules

### Pattern 1: Utility Functions

**File: `lua/helpers/utils.lua`**

```lua
local M = {}

--- Check if a plugin is loaded
--- @param plugin string Plugin name
--- @return boolean
function M.has_plugin(plugin)
  return package.loaded[plugin] ~= nil
end

--- Safe require with default fallback
--- @param module string Module name
--- @param default any Default value if module not found
--- @return any Module or default
function M.safe_require(module, default)
  local ok, result = pcall(require, module)
  return ok and result or default
end

--- Get OS type
--- @return "linux"|"mac"|"windows"
function M.get_os()
  if vim.fn.has("mac") == 1 then
    return "mac"
  elseif vim.fn.has("win32") == 1 then
    return "windows"
  else
    return "linux"
  end
end

return M
```

---

### Pattern 2: Keymap Helpers (Your Pattern)

**File: `lua/helpers/keys.lua`**

```lua
local M = {}

--- Create a keymap
--- @param mode string|table Mode(s)
--- @param lhs string Left-hand side
--- @param rhs string|function Right-hand side
--- @param desc string Description
function M.map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    silent = true,
    desc = desc,
    noremap = true
  })
end

--- Create an LSP keymap
--- @param mode string|table Mode(s)
--- @param lhs string Left-hand side
--- @param rhs string|function Right-hand side
--- @param desc string Description
function M.lsp_map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    silent = true,
    buffer = true,
    noremap = true,
    desc = "LSP - " .. desc
  })
end

--- Set leader key
--- @param key string Leader key
function M.set_leader(key)
  vim.g.mapleader = key
  vim.g.maplocalleader = key
  M.map({ "n", "v" }, key, "<nop>")
end

return M
```

**Usage:**

```lua
local map = require("helpers.keys").map

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", "Find files")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", "Live grep")
```

---

### Pattern 3: LSP Helpers

**File: `lua/helpers/lsp.lua`**

```lua
local M = {}

--- Check if LSP client supports method
--- @param client table LSP client
--- @param method string LSP method name
--- @return boolean
function M.supports_method(client, method)
  return client.supports_method(method)
end

--- Format buffer with LSP
--- @param bufnr number Buffer number
function M.format(bufnr)
  vim.lsp.buf.format({
    async = false,
    bufnr = bufnr,
    filter = function(client)
      -- Only use specific formatters
      return client.name ~= "tsserver"
    end
  })
end

--- Get active LSP clients for buffer
--- @param bufnr number Buffer number
--- @return table[] List of clients
function M.get_clients(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr })
end

return M
```

---

## Autocommands and Keymaps

### Autocommands Module

**File: `lua/config/autocmds.lua`**

```lua
-- Create autocommand groups
local augroups = {
  highlight_yank = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
  format_on_save = vim.api.nvim_create_augroup("FormatOnSave", { clear = true }),
  resize_splits = vim.api.nvim_create_augroup("ResizeSplits", { clear = true }),
}

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroups.highlight_yank,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
  desc = "Highlight yanked text",
})

-- Auto-resize splits when terminal is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = augroups.resize_splits,
  callback = function()
    vim.cmd("wincmd =")
  end,
  desc = "Resize splits on terminal resize",
})

-- Format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroups.format_on_save,
  callback = function(args)
    require("helpers.lsp").format(args.buf)
  end,
  desc = "Format buffer on save",
})
```

---

### Keymaps Module

**File: `lua/config/keymaps.lua`**

```lua
local map = require("helpers.keys").map

-- Leader key (set first!)
require("helpers.keys").set_leader("\\")

-- Better window navigation
map("n", "<C-h>", "<C-w>h", "Move to left window")
map("n", "<C-j>", "<C-w>j", "Move to bottom window")
map("n", "<C-k>", "<C-w>k", "Move to top window")
map("n", "<C-l>", "<C-w>l", "Move to right window")

-- Buffer navigation
map("n", "<leader>bn", "<cmd>bnext<cr>", "Next buffer")
map("n", "<leader>bp", "<cmd>bprevious<cr>", "Previous buffer")
map("n", "<leader>bd", "<cmd>bdelete<cr>", "Delete buffer")

-- Quick save
map("n", "<leader>w", "<cmd>write<cr>", "Save file")

-- Escape from terminal mode
map("t", "<Esc>", "<C-\\><C-n>", "Exit terminal mode")

-- Visual mode: keep selection after indent
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")

-- Search centering
map("n", "n", "nzzzv", "Next search result (centered)")
map("n", "N", "Nzzzv", "Previous search result (centered)")
```

---

## Best Practices

### 1. Use Descriptive Module Names

```lua
-- BAD
require("a")
require("stuff")
require("config2")

-- GOOD
require("config.options")
require("plugins.lsp")
require("helpers.utils")
```

---

### 2. Keep Modules Focused

Each module should have a single responsibility:

```lua
-- config/options.lua - Only Vim options
-- config/keymaps.lua - Only keymaps
-- config/autocmds.lua - Only autocommands
-- plugins/lsp.lua - Only LSP plugins
```

---

### 3. Use init.lua for Index Files

**Directory structure:**
```
lua/mymodule/
├── init.lua       # Main entry point
├── utils.lua      # Utilities
└── config.lua     # Configuration
```

**File: `lua/mymodule/init.lua`**

```lua
local M = {}

-- Re-export submodules
M.utils = require("mymodule.utils")
M.config = require("mymodule.config")

-- Main function
function M.setup(opts)
  M.config.setup(opts)
end

return M
```

**Usage:**

```lua
local mymodule = require("mymodule")
mymodule.setup({ theme = "dark" })
```

---

### 4. Document Modules

```lua
--- LSP helper utilities
--- @module helpers.lsp
local M = {}

--- Format buffer using LSP
--- @param bufnr number Buffer number (0 for current)
--- @param timeout? number Timeout in milliseconds
--- @return boolean success Whether formatting succeeded
function M.format(bufnr, timeout)
  -- implementation
end

return M
```

---

### 5. Avoid Circular Dependencies

```lua
-- BAD: Circular dependency
-- moduleA.lua
local B = require("moduleB")

-- moduleB.lua
local A = require("moduleA")  -- ERROR! Circular dependency

-- GOOD: Restructure to avoid circularity
-- Create a shared module for common functionality
```

---

### 6. Use Protected Calls for Optional Dependencies

```lua
-- Plugin configuration that might not be available
local ok, telescope = pcall(require, "telescope")
if not ok then
  vim.notify("Telescope not installed", vim.log.levels.WARN)
  return {}  -- Return empty plugin spec
end

-- Use telescope...
```

---

### 7. Separate Configuration from Plugin Specs

**File: `lua/plugins/telescope.lua`**

```lua
return {
  {
    "nvim-telescope/telescope.nvim",
    config = function()
      require("config.telescope_setup")
    end,
  },
}
```

**File: `lua/config/telescope_setup.lua`**

```lua
-- Complex configuration logic
local telescope = require("telescope")

-- Custom setup
telescope.setup({
  -- lots of config...
})
```

**Benefit:** Easier to test and modify configuration independently.

---

## Example: Complete Module Refactor

### Before (Single File)

**File: `init.lua`**

```lua
-- 500 lines of mixed config...
vim.opt.number = true
vim.opt.relativenumber = true
-- ...

vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
-- ...

vim.api.nvim_create_autocmd("TextYankPost", {
  -- ...
})
-- ...
```

### After (Modular)

**File: `init.lua`**

```lua
vim.loader.enable()

-- Load configuration modules
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")  -- Plugin manager
```

**File: `lua/config/options.lua`**

```lua
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
-- ... all options
```

**File: `lua/config/keymaps.lua`**

```lua
local map = require("helpers.keys").map

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", "Find files")
-- ... all keymaps
```

**File: `lua/config/autocmds.lua`**

```lua
local augroup = vim.api.nvim_create_augroup

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("HighlightYank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
-- ... all autocommands
```

---

## Troubleshooting

### Module Not Found

```lua
-- Error: module 'mymodule' not found

-- Check:
-- 1. File exists at lua/mymodule.lua or lua/mymodule/init.lua
-- 2. File has no syntax errors
-- 3. Path is correct (use require("mymodule"), not require("lua/mymodule"))
```

### Module Caching Issues

```lua
-- Clear module cache for development
package.loaded["mymodule"] = nil
local fresh = require("mymodule")

-- Or create a reload helper
local function reload(module)
  package.loaded[module] = nil
  return require(module)
end

local m = reload("mymodule")
```

### Circular Dependencies

```
Error: loop or previous error loading module 'moduleA'

-- Solution: Restructure modules to avoid circular references
-- Move shared code to a third module
```

---

## Next Steps

Continue learning:
- **[Lua Basics](lua-basics.md)** - Lua language fundamentals
- **[Neovim Lua API](neovim-lua-api.md)** - Neovim-specific APIs
- **[Lua Recipes](lua-recipes.md)** - Practical examples

---

*Tutorial Version: 1.0*
*Last Updated: 2025-10-12*
