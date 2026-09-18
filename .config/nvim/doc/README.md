# Neovim Configuration Documentation

**Welcome to your Neovim Lua learning resource!**

This documentation provides comprehensive tutorials and guides for learning Lua scripting in Neovim, from fundamentals to advanced patterns.

---

## Quick Links

- **[Keymap Reference](KEYMAP.md)** - Every custom keybinding in this config, by plugin
- **[Lua Basics](lua-basics.md)** - Start here if you're new to Lua
- **[Module Organization](module-organization.md)** - Structure your configuration
- **[Neovim Lua API](neovim-lua-api.md)** - Complete API reference
- **[Lua Recipes](lua-recipes.md)** - Practical examples and patterns
- **[Plugin Development](plugin-development.md)** - Build custom Neovim plugins 🆕
- **[Plugin Templates](plugin-templates.md)** - Ready-to-use plugin templates 🆕

---

## Learning Path

### Level 1: Beginner (Start Here!)

**Goal:** Understand Lua fundamentals and basic Neovim configuration

1. **[Lua Basics](lua-basics.md)**
   - Data types and variables
   - Tables (Lua's core data structure)
   - Functions and closures
   - Control flow and loops
   - Error handling with `pcall()`
   - Estimated time: 2-3 hours

2. **[Module Organization](module-organization.md)** - Sections 1-3
   - Why organize configuration?
   - Directory structure
   - Module loading with `require()`
   - Estimated time: 1 hour

**Practice Project:** Create a simple `hello.lua` module that exports a greeting function

```lua
-- lua/hello.lua
local M = {}

function M.greet(name)
  print("Hello, " .. (name or "World") .. "!")
end

return M

-- Usage in init.lua:
-- require("hello").greet("Neovim")
```

---

### Level 2: Intermediate

**Goal:** Learn Neovim-specific APIs and configuration patterns

3. **[Neovim Lua API](neovim-lua-api.md)** - Core APIs
   - `vim.api` - Buffer, window, autocommand operations
   - `vim.opt` - Option management
   - `vim.keymap` - Keymap creation
   - `vim.fn` - Vim functions
   - Estimated time: 3-4 hours

4. **[Module Organization](module-organization.md)** - Sections 4-7
   - Plugin organization patterns
   - Helper modules
   - Configuration patterns
   - Estimated time: 2 hours

**Practice Project:** Reorganize your `init.lua` into modules

```
Before:
  init.lua (300 lines)

After:
  init.lua (10 lines)
  lua/config/options.lua
  lua/config/keymaps.lua
  lua/config/autocmds.lua
```

---

### Level 3: Advanced

**Goal:** Master LSP, diagnostics, and advanced patterns

5. **[Neovim Lua API](neovim-lua-api.md)** - Advanced APIs
   - `vim.lsp` - LSP client
   - `vim.diagnostic` - Diagnostics
   - `vim.treesitter` - Syntax trees
   - `vim.fs` - File system operations
   - Estimated time: 3-4 hours

6. **[Lua Recipes](lua-recipes.md)**
   - Keymap recipes
   - Autocommand patterns
   - LSP customizations
   - UI enhancements
   - Estimated time: 2-3 hours (read through examples)

**Practice Project:** Create a custom LSP configuration module

```lua
-- lua/helpers/lsp.lua
local M = {}

function M.setup()
  -- Custom LSP setup
end

function M.format(bufnr)
  -- Custom formatting logic
end

return M
```

---

### Level 4: Expert

**Goal:** Build custom plugins and advanced configurations

7. **[Lua Recipes](lua-recipes.md)** - Advanced Patterns
   - Plugin manager patterns
   - Event bus
   - Complete plugin example
   - Testing and debugging
   - Estimated time: 4-6 hours

**Practice Project:** Build a custom plugin

8. **[Plugin Development](plugin-development.md)**
   - 2025 plugin trends
   - 11 plugin project ideas (beginner to advanced)
   - Complete tutorials with code
   - Plugin manager compatibility
   - Estimated time: 8-12 hours

9. **[Plugin Templates](plugin-templates.md)**
   - Copy-paste templates
   - Quick-start script
   - Testing setup
   - CI/CD configuration
   - Estimated time: Reference material

Example projects: Session manager, TODO finder, AI code assistant

---

## Document Overview

### [Keymap Reference](KEYMAP.md)

**Purpose:** Ground truth for every custom keybinding in this config

**Contents:**
- Full leader/localleader design rationale
- Every mapping grouped by plugin, cross-checked against the actual `lua/plugins/*.lua` source

**Best for:**
- Looking up what a key does before pressing it
- Checking whether a key is already taken before adding a new mapping

---

### [Lua Basics](lua-basics.md)

**Purpose:** Learn Lua language fundamentals

**Contents:**
- Data types and variables
- Tables (arrays, dictionaries, objects)
- Functions (first-class, higher-order)
- Modules and require()
- Closures and scoping
- Error handling
- Iterators and loops
- Metatables
- Best practices

**Best for:**
- Lua beginners
- Those transitioning from VimScript
- Understanding core concepts

**Key Highlights:**
- 📚 Complete Lua tutorial
- 💡 Practical examples
- ⚠️ Common pitfalls
- 🎯 Quick reference table

---

### [Module Organization](module-organization.md)

**Purpose:** Structure your Neovim configuration effectively

**Contents:**
- Directory structure recommendations
- Module loading patterns
- Configuration entry points
- Plugin organization strategies
- Helper module patterns
- Best practices
- Troubleshooting

**Best for:**
- Organizing growing configs
- Understanding module systems
- Creating maintainable code

**Key Highlights:**
- 📁 4 directory structure patterns
- 🔌 4 plugin organization approaches
- 🛠️ Helper module examples
- ✅ Complete refactor example

---

### [Neovim Lua API](neovim-lua-api.md)

**Purpose:** Complete reference for Neovim's Lua APIs

**Contents:**
- `vim.api` - Core Neovim API
- `vim.fn` - Vim functions
- `vim.opt` - Options API
- `vim.keymap` - Keymap management
- `vim.diagnostic` - Diagnostics
- `vim.lsp` - LSP client (0.11+)
- `vim.treesitter` - Syntax trees
- `vim.fs` - File system (0.11+)
- `vim.uv` - Async I/O
- Utility APIs

**Best for:**
- API reference
- Finding the right function
- Understanding vim.* namespaces

**Key Highlights:**
- 📖 Comprehensive API coverage
- 🆕 Neovim 0.11+ features highlighted
- 💻 Code examples for each API
- 🔗 Links to official documentation

---

### [Lua Recipes](lua-recipes.md)

**Purpose:** Practical, copy-paste examples for common tasks

**Contents:**
- Configuration patterns
- Keymap recipes
- Autocommand patterns
- LSP customizations
- UI enhancements
- File operations
- Buffer/window management
- Plugin integration
- Utility functions
- Advanced patterns
- Complete plugin example

**Best for:**
- Solving specific problems
- Learning by example
- Copy-paste snippets

**Key Highlights:**
- 🍳 50+ practical recipes
- 📋 Ready-to-use code
- 🎨 UI enhancement patterns
- 🚀 Complete plugin example
- 🐛 Debugging tips

---

### [Plugin Development](plugin-development.md)

**Purpose:** Learn to build custom Neovim plugins

**Contents:**
- 2025 plugin trends and popular plugins
- 11 project ideas (beginner to advanced)
- Session Manager tutorial (complete code)
- TODO Finder tutorial (treesitter)
- AI Assistant tutorial (async/API integration)
- Plugin manager compatibility (lazy.nvim, packer, vim-plug)
- Publishing guide

**Best for:**
- Building custom tools
- Learning advanced Lua patterns
- Understanding plugin architecture
- Contributing to Neovim ecosystem

**Key Highlights:**
- 🎯 11 project ideas with difficulty levels
- 📝 3 complete tutorials with full code
- 🔌 Multi-plugin-manager support
- 🚀 Publishing and testing guides

---

### [Plugin Templates](plugin-templates.md)

**Purpose:** Quick-start templates for plugin development

**Contents:**
- Minimal plugin template
- Configuration management template
- UI/floating window template
- External command execution template
- Treesitter integration template
- LSP integration template
- Testing template
- CI/CD template
- Quick-start shell script

**Best for:**
- Starting new plugin projects
- Copy-paste boilerplate
- Reference implementations
- Rapid prototyping

**Key Highlights:**
- 📦 7 ready-to-use templates
- 🛠️ Quick-start automation script
- ✅ Testing and CI/CD setups
- 📋 Best practices included

---

## Quick Start Examples

### Example 1: Create Your First Module

```lua
-- File: lua/myconfig/init.lua
local M = {}

-- Configuration state
M.options = {
  theme = "dark",
  font_size = 14,
}

-- Setup function
function M.setup(opts)
  M.options = vim.tbl_extend("force", M.options, opts or {})
end

-- Get option value
function M.get(key)
  return M.options[key]
end

return M
```

**Usage:**

```lua
-- In init.lua
local myconfig = require("myconfig")
myconfig.setup({ theme = "light" })
print(myconfig.get("theme"))  -- "light"
```

---

### Example 2: Create a Keymap Helper

```lua
-- File: lua/helpers/keys.lua
local M = {}

function M.map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    silent = true,
    noremap = true,
    desc = desc,
  })
end

return M
```

**Usage:**

```lua
-- In lua/config/keymaps.lua
local map = require("helpers.keys").map

map("n", "<leader>w", "<cmd>write<cr>", "Save file")
map("n", "<leader>q", "<cmd>quit<cr>", "Quit")
```

---

### Example 3: Configure LSP (Neovim 0.11+)

```lua
-- File: lua/config/lsp.lua

-- Configure diagnostics
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Setup LSP on attach
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    -- Enable inlay hints
    if client.supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end

    -- Keymaps
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
      buffer = bufnr,
      desc = "Go to definition"
    })

    vim.keymap.set("n", "K", vim.lsp.buf.hover, {
      buffer = bufnr,
      desc = "Hover documentation"
    })
  end,
})

-- Enable language servers (0.11+)
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
    },
  },
})

vim.lsp.enable("lua_ls")
```

---

## Useful Commands

### Inside Neovim

```vim
" View Lua help
:help lua
:help lua-guide
:help vim.api

" Execute Lua code
:lua print("Hello, Neovim!")
:lua vim.notify("Test notification")

" Run Lua file
:luafile ~/.config/nvim/test.lua

" Inspect variable
:lua print(vim.inspect(vim.opt.number:get()))

" Check health
:checkhealth

" LSP info
:LspInfo
:LspLog

" Treesitter info
:TSInstallInfo
```

### Testing Your Configuration

```lua
-- Add to init.lua for development
if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("Please upgrade to Neovim 0.11+", vim.log.levels.ERROR)
end

-- Benchmark startup time
-- Run: nvim --startuptime startup.log +qall && cat startup.log

-- Profile Lua modules
-- Add at top of init.lua:
-- require("jit.p").start("vl")
-- require("jit.p").stop()
```

---

## Troubleshooting

### Common Issues

**Issue:** Module not found

```
Error: module 'mymodule' not found
```

**Solution:**
- Check file exists at `lua/mymodule.lua` or `lua/mymodule/init.lua`
- Use correct path: `require("mymodule")` not `require("lua/mymodule")`
- Check for syntax errors in the module

---

**Issue:** Circular dependency

```
Error: loop or previous error loading module 'moduleA'
```

**Solution:**
- Restructure modules to avoid circular references
- Move shared code to a third module
- Use lazy loading with `vim.defer_fn()`

---

**Issue:** Option not working

```lua
vim.opt.number = true  -- Not working?
```

**Solution:**
- Check if option exists: `:help 'number'`
- Use correct scope: `vim.opt_local` for buffer-local options
- Some options require restart

---

### Debugging Tips

```lua
-- 1. Print with inspect
P = function(v)
  print(vim.inspect(v))
  return v
end

-- Usage: P(vim.opt.number:get())

-- 2. Reload module
RELOAD = function(module_name)
  package.loaded[module_name] = nil
  return require(module_name)
end

-- Usage: RELOAD("mymodule")

-- 3. Check if module loaded
if package.loaded["mymodule"] then
  print("Module is loaded")
end

-- 4. View all loaded modules
P(vim.tbl_keys(package.loaded))
```

---

## Additional Resources

### Official Documentation

- **Neovim Docs:** https://neovim.io/doc/
- **`:help lua`** - Lua integration
- **`:help lua-guide`** - Lua guide for Neovim
- **`:help api`** - API documentation

### Community Resources

- **r/neovim:** https://reddit.com/r/neovim
- **Neovim Discourse:** https://neovim.discourse.group/
- **GitHub Discussions:** https://github.com/neovim/neovim/discussions

### Example Configurations

Study well-organized configs:
- **LazyVim:** https://github.com/LazyVim/LazyVim
- **NvChad:** https://github.com/NvChad/NvChad
- **AstroNvim:** https://github.com/AstroNvim/AstroNvim

### Recommended Readings

- **Learn Lua in Y Minutes:** https://learnxinyminutes.com/docs/lua/
- **Programming in Lua:** https://www.lua.org/pil/
- **Neovim News:** https://neovim.io/news/

---

## Your Configuration Checklist

Use this checklist to track your progress:

### Fundamentals
- [ ] Understand Lua data types and tables
- [ ] Can write and use functions
- [ ] Understand module system (`require()`)
- [ ] Know how to handle errors (`pcall()`)

### Configuration
- [ ] Organized init.lua with modules
- [ ] Separated options, keymaps, autocmds
- [ ] Created helper functions
- [ ] Using lazy loading for plugins

### APIs
- [ ] Comfortable with `vim.api` basics
- [ ] Can set options with `vim.opt`
- [ ] Can create keymaps with `vim.keymap`
- [ ] Can write autocommands

### Advanced
- [ ] Configured LSP with Neovim 0.11+ APIs
- [ ] Using diagnostics and inlay hints
- [ ] Created custom commands
- [ ] Built a custom plugin or module

### Plugin Development
- [ ] Understand plugin structure and organization
- [ ] Built a beginner-level plugin (e.g., Session Manager)
- [ ] Created plugin with UI (floating windows)
- [ ] Integrated with treesitter or LSP
- [ ] Published plugin to GitHub
- [ ] Made plugin compatible with multiple plugin managers

### Performance
- [ ] Applied performance optimizations
- [ ] Enabled treesitter async features
- [ ] Benchmarked startup time
- [ ] Using `vim.loader.enable()`

---

## Contributing

Found an error or want to add content? Create an issue or PR!

This documentation is part of your personal Neovim configuration. Feel free to:
- Add your own notes
- Customize examples
- Share with others

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2025-10-12 | Added plugin development guides and templates |
| 1.0 | 2025-10-12 | Initial documentation release |

---

**Happy Vimming!** 🚀

*If you find this documentation helpful, consider starring the repo or sharing with others learning Neovim!*

---

*Documentation Version: 1.0*
*Last Updated: 2025-10-12*
*Neovim Version: 0.11+*
