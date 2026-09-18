# Plugin Development Templates

**Quick-start templates for Neovim plugins**
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [Minimal Plugin Template](#minimal-plugin-template)
2. [Plugin with Configuration](#plugin-with-configuration)
3. [Plugin with UI](#plugin-with-ui)
4. [Plugin with External Commands](#plugin-with-external-commands)
5. [Plugin with Treesitter](#plugin-with-treesitter)
6. [Plugin with LSP](#plugin-with-lsp)
7. [Testing Template](#testing-template)

---

## Minimal Plugin Template

The absolute minimum structure for a working plugin.

### File Structure

```
my-plugin.nvim/
├── lua/
│   └── my-plugin/
│       └── init.lua
├── plugin/
│   └── my-plugin.lua
└── README.md
```

### `lua/my-plugin/init.lua`

```lua
local M = {}

--- Setup function (called by user)
--- @param opts table|nil User configuration
function M.setup(opts)
  opts = opts or {}
  -- Plugin initialization
  print("My plugin loaded!")
end

--- Your plugin functions
function M.hello()
  vim.notify("Hello from my plugin!", vim.log.levels.INFO)
end

return M
```

### `plugin/my-plugin.lua`

```lua
-- Auto-loaded on startup (optional)
if vim.g.loaded_my_plugin then
  return
end
vim.g.loaded_my_plugin = true

-- Create commands
vim.api.nvim_create_user_command("MyPluginHello", function()
  require("my-plugin").hello()
end, { desc = "Say hello" })
```

### Installation (lazy.nvim)

```lua
{
  dir = "path/to/my-plugin.nvim",
  config = function()
    require("my-plugin").setup()
  end,
}
```

---

## Plugin with Configuration

Template for plugins that need user configuration.

### `lua/my-plugin/config.lua`

```lua
local M = {}

-- Default configuration
M.defaults = {
  enabled = true,
  auto_save = false,
  keymaps = {
    save = "<leader>s",
    load = "<leader>l",
  },
  ui = {
    border = "rounded",
    width = 0.8,
    height = 0.8,
  },
}

-- Current configuration
M.options = {}

--- Setup configuration
--- @param opts table User options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Get configuration value
--- @param key string Configuration key (supports dot notation)
--- @return any Configuration value
function M.get(key)
  local keys = vim.split(key, ".", { plain = true })
  local value = M.options

  for _, k in ipairs(keys) do
    if type(value) ~= "table" then
      return nil
    end
    value = value[k]
  end

  return value
end

--- Validate configuration
--- @return boolean, string|nil Success, error message
function M.validate()
  vim.validate({
    enabled = { M.options.enabled, "boolean" },
    auto_save = { M.options.auto_save, "boolean" },
    keymaps = { M.options.keymaps, "table" },
    ui = { M.options.ui, "table" },
  })

  return true, nil
end

return M
```

### `lua/my-plugin/init.lua`

```lua
local M = {}
local config = require("my-plugin.config")

function M.setup(opts)
  config.setup(opts)

  local ok, err = config.validate()
  if not ok then
    vim.notify("My Plugin: Invalid configuration - " .. err, vim.log.levels.ERROR)
    return
  end

  -- Setup based on configuration
  if config.get("auto_save") then
    M._setup_auto_save()
  end
end

function M._setup_auto_save()
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      print("Auto-saving...")
    end,
  })
end

return M
```

---

## Plugin with UI

Template for plugins with floating windows and UI.

### `lua/my-plugin/ui.lua`

```lua
local M = {}
local config = require("my-plugin.config")

--- Create centered floating window
--- @param opts table Window options
--- @return number bufnr Buffer number
--- @return number winnr Window number
function M.create_float(opts)
  opts = opts or {}

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Calculate dimensions
  local width = opts.width or math.floor(vim.o.columns * config.get("ui.width"))
  local height = opts.height or math.floor(vim.o.lines * config.get("ui.height"))

  -- Calculate position
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Window options
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.get("ui.border"),
    title = opts.title or " My Plugin ",
    title_pos = "center",
  }

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set window options
  vim.api.nvim_win_set_option(win, "winblend", 0)
  vim.api.nvim_win_set_option(win, "cursorline", true)

  -- Add close keymap
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true })

  return buf, win
end

--- Show a list in floating window
--- @param items table List of items
--- @param opts table Options
function M.show_list(items, opts)
  opts = opts or {}

  local buf, win = M.create_float({
    title = opts.title or " Select Item ",
  })

  -- Render items
  local lines = {}
  for i, item in ipairs(items) do
    local line = string.format("%d. %s", i, item.text or tostring(item))
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Selection handler
  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local selected = items[row]

    if opts.on_select then
      opts.on_select(selected)
    end

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf })

  return buf, win
end

--- Show loading indicator
--- @param message string Loading message
--- @return number bufnr Buffer number
--- @return number winnr Window number
function M.show_loading(message)
  local buf, win = M.create_float({
    title = " Please Wait ",
    width = 40,
    height = 3,
  })

  local lines = { "", "  " .. message, "" }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  return buf, win
end

--- Update buffer content
--- @param buf number Buffer number
--- @param lines string[] New lines
function M.update_buffer(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
```

---

## Plugin with External Commands

Template for plugins that execute external commands.

### `lua/my-plugin/commands.lua`

```lua
local M = {}

--- Execute external command asynchronously
--- @param cmd string|table Command to execute
--- @param opts table Options
--- @return number Job ID
function M.async_exec(cmd, opts)
  opts = opts or {}

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local stdout_data = {}
  local stderr_data = {}

  local handle, pid
  handle, pid = vim.loop.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { nil, stdout, stderr },
    cwd = opts.cwd,
  }, function(code, signal)
    stdout:close()
    stderr:close()
    handle:close()

    vim.schedule(function()
      if opts.on_exit then
        opts.on_exit(code, signal, stdout_data, stderr_data)
      end
    end)
  end)

  if not handle then
    return nil
  end

  -- Read stdout
  stdout:read_start(function(err, data)
    assert(not err, err)
    if data then
      table.insert(stdout_data, data)
      if opts.on_stdout then
        vim.schedule(function()
          opts.on_stdout(data)
        end)
      end
    end
  end)

  -- Read stderr
  stderr:read_start(function(err, data)
    assert(not err, err)
    if data then
      table.insert(stderr_data, data)
      if opts.on_stderr then
        vim.schedule(function()
          opts.on_stderr(data)
        end)
      end
    end
  end)

  return pid
end

--- Execute command synchronously
--- @param cmd string|table Command
--- @param opts table Options
--- @return string stdout Output
--- @return string stderr Error output
--- @return number code Exit code
function M.sync_exec(cmd, opts)
  opts = opts or {}

  local result = vim.fn.system(cmd)
  local code = vim.v.shell_error

  return result, "", code
end

--- Execute git command
--- @param args string[] Git arguments
--- @param opts table Options
--- @return string|nil Output or nil on error
function M.git(args, opts)
  opts = opts or {}

  local cmd = vim.list_extend({ "git" }, args)
  local stdout, stderr, code = M.sync_exec(cmd, opts)

  if code ~= 0 then
    if opts.on_error then
      opts.on_error(stderr)
    else
      vim.notify("Git error: " .. stderr, vim.log.levels.ERROR)
    end
    return nil
  end

  return stdout
end

--- Check if command exists
--- @param cmd string Command name
--- @return boolean
function M.command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

return M
```

### Example Usage

```lua
local commands = require("my-plugin.commands")

-- Async git status
commands.async_exec({ "git", "status", "--porcelain" }, {
  on_stdout = function(data)
    print("Output:", data)
  end,
  on_exit = function(code)
    print("Exit code:", code)
  end,
})

-- Sync git log
local output = commands.git({ "log", "--oneline", "-n", "10" })
print(output)
```

---

## Plugin with Treesitter

Template for plugins that use treesitter queries.

### `lua/my-plugin/treesitter.lua`

```lua
local M = {}

--- Get treesitter parser for buffer
--- @param bufnr number Buffer number
--- @return table|nil Parser or nil
function M.get_parser(bufnr)
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok then
    return nil
  end

  return parser
end

--- Parse treesitter query
--- @param lang string Language
--- @param query_string string Query string
--- @return table|nil Query or nil
function M.parse_query(lang, query_string)
  local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
  if not ok then
    vim.notify("Failed to parse query: " .. query, vim.log.levels.ERROR)
    return nil
  end

  return query
end

--- Find all functions in buffer
--- @param bufnr number Buffer number
--- @return table[] List of functions with name and location
function M.find_functions(bufnr)
  bufnr = bufnr or 0

  local parser = M.get_parser(bufnr)
  if not parser then
    return {}
  end

  local lang = parser:lang()
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for functions (works for lua, python, etc.)
  local query_string = [[
    (function_declaration
      name: (identifier) @name) @func

    (function_definition
      name: (identifier) @name) @func
  ]]

  local query = M.parse_query(lang, query_string)
  if not query then
    return {}
  end

  local functions = {}

  for id, node in query:iter_captures(root, bufnr) do
    if query.captures[id] == "name" then
      local name = vim.treesitter.get_node_text(node, bufnr)
      local row, col = node:start()

      table.insert(functions, {
        name = name,
        lnum = row + 1,
        col = col + 1,
        node = node,
      })
    end
  end

  return functions
end

--- Get node at cursor
--- @param bufnr number Buffer number
--- @return table|nil Node or nil
function M.get_node_at_cursor(bufnr)
  bufnr = bufnr or 0

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1  -- 0-indexed

  local parser = M.get_parser(bufnr)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  return root:descendant_for_range(row, col, row, col)
end

--- Get parent node of type
--- @param node table Node
--- @param type string Node type
--- @return table|nil Parent node or nil
function M.get_parent_of_type(node, type)
  local parent = node:parent()

  while parent do
    if parent:type() == type then
      return parent
    end
    parent = parent:parent()
  end

  return nil
end

return M
```

---

## Plugin with LSP

Template for plugins that integrate with LSP.

### `lua/my-plugin/lsp.lua`

```lua
local M = {}

--- Get active LSP clients for buffer
--- @param bufnr number Buffer number
--- @return table[] List of clients
function M.get_clients(bufnr)
  bufnr = bufnr or 0
  return vim.lsp.get_clients({ bufnr = bufnr })
end

--- Check if LSP is attached
--- @param bufnr number Buffer number
--- @return boolean
function M.is_attached(bufnr)
  bufnr = bufnr or 0
  return #M.get_clients(bufnr) > 0
end

--- Get client by name
--- @param name string Client name
--- @param bufnr number Buffer number
--- @return table|nil Client or nil
function M.get_client_by_name(name, bufnr)
  for _, client in ipairs(M.get_clients(bufnr)) do
    if client.name == name then
      return client
    end
  end
  return nil
end

--- Request LSP method
--- @param method string LSP method
--- @param params table Parameters
--- @param callback function Callback function
--- @param bufnr number Buffer number
function M.request(method, params, callback, bufnr)
  bufnr = bufnr or 0

  vim.lsp.buf_request(bufnr, method, params, function(err, result, ctx)
    if err then
      vim.notify("LSP error: " .. err.message, vim.log.levels.ERROR)
      return
    end

    callback(result, ctx)
  end)
end

--- Get document symbols
--- @param bufnr number Buffer number
--- @param callback function Callback function
function M.get_document_symbols(bufnr, callback)
  bufnr = bufnr or 0

  M.request("textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }, callback, bufnr)
end

--- Go to definition
--- @param bufnr number Buffer number
function M.goto_definition(bufnr)
  bufnr = bufnr or 0

  M.request("textDocument/definition", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = vim.lsp.util.make_position_params().position,
  }, function(result)
    if not result or vim.tbl_isempty(result) then
      vim.notify("No definition found", vim.log.levels.INFO)
      return
    end

    vim.lsp.util.jump_to_location(result[1], "utf-8")
  end, bufnr)
end

--- Format buffer
--- @param bufnr number Buffer number
--- @param callback function|nil Callback function
function M.format(bufnr, callback)
  bufnr = bufnr or 0

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = callback ~= nil,
  }, callback)
end

return M
```

---

## Testing Template

Template for testing your plugin with plenary.nvim.

### `tests/init_spec.lua`

```lua
local plugin = require("my-plugin")

describe("my-plugin", function()
  before_each(function()
    -- Reset state before each test
    plugin.setup({})
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  describe("setup", function()
    it("loads without errors", function()
      local ok = pcall(plugin.setup, {})
      assert.is_true(ok)
    end)

    it("accepts custom configuration", function()
      plugin.setup({
        enabled = false,
      })

      local config = require("my-plugin.config")
      assert.is_false(config.get("enabled"))
    end)
  end)

  describe("functionality", function()
    it("has required functions", function()
      assert.is_function(plugin.setup)
      assert.is_function(plugin.hello)
    end)

    it("creates commands", function()
      plugin.setup({})

      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.MyPluginHello)
    end)
  end)
end)
```

### Run Tests

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

### `tests/minimal_init.lua`

```lua
-- Minimal init for testing
local lazypath = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "https://github.com/nvim-lua/plenary.nvim",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Add plugin to runtime path
vim.opt.rtp:prepend(".")
```

---

## GitHub Actions CI Template

### `.github/workflows/test.yml`

```yaml
name: Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        nvim-version: ['stable', 'nightly']

    steps:
      - uses: actions/checkout@v3

      - name: Setup Neovim
        uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.nvim-version }}

      - name: Install dependencies
        run: |
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim

      - name: Run tests
        run: |
          nvim --version
          nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

      - name: Run luacheck
        uses: luarocks/luacheck-action@v1
        with:
          args: lua/ tests/
```

---

## Complete Example: Quick Start Script

Create a new plugin quickly with this script:

### `create-plugin.sh`

```bash
#!/bin/bash

# Usage: ./create-plugin.sh my-awesome-plugin

PLUGIN_NAME=$1

if [ -z "$PLUGIN_NAME" ]; then
  echo "Usage: $0 plugin-name"
  exit 1
fi

PLUGIN_DIR="${PLUGIN_NAME}.nvim"

echo "Creating plugin: $PLUGIN_DIR"

# Create directory structure
mkdir -p "$PLUGIN_DIR"/{lua/$PLUGIN_NAME,plugin,doc,tests}

# Create main module
cat > "$PLUGIN_DIR/lua/$PLUGIN_NAME/init.lua" << 'EOF'
local M = {}

function M.setup(opts)
  opts = opts or {}
  vim.notify("Plugin loaded!", vim.log.levels.INFO)
end

return M
EOF

# Create plugin file
cat > "$PLUGIN_DIR/plugin/$PLUGIN_NAME.lua" << EOF
if vim.g.loaded_${PLUGIN_NAME//-/_} then
  return
end
vim.g.loaded_${PLUGIN_NAME//-/_} = true

-- Auto-setup with defaults
require("$PLUGIN_NAME").setup()
EOF

# Create README
cat > "$PLUGIN_DIR/README.md" << EOF
# $PLUGIN_NAME

Description of your plugin.

## Installation

### lazy.nvim

\`\`\`lua
{
  "username/$PLUGIN_DIR",
  config = function()
    require("$PLUGIN_NAME").setup()
  end,
}
\`\`\`

## Usage

TODO: Add usage instructions

## Configuration

TODO: Add configuration options

## License

MIT
EOF

# Create test file
cat > "$PLUGIN_DIR/tests/init_spec.lua" << EOF
describe("$PLUGIN_NAME", function()
  it("loads", function()
    local ok = pcall(require, "$PLUGIN_NAME")
    assert.is_true(ok)
  end)
end)
EOF

# Create .gitignore
cat > "$PLUGIN_DIR/.gitignore" << 'EOF'
.DS_Store
*.swp
*.swo
*~
EOF

# Initialize git
cd "$PLUGIN_DIR"
git init
git add .
git commit -m "Initial commit"

echo "Plugin created successfully in $PLUGIN_DIR!"
echo "Next steps:"
echo "  1. cd $PLUGIN_DIR"
echo "  2. Edit lua/$PLUGIN_NAME/init.lua"
echo "  3. Add your plugin to your Neovim config"
```

Make it executable:

```bash
chmod +x create-plugin.sh
./create-plugin.sh my-awesome-plugin
```

---

## Resources

- **[Plugin Development Guide](plugin-development.md)** - Complete guide
- **[Lua Basics](lua-basics.md)** - Lua fundamentals
- **[Neovim Lua API](neovim-lua-api.md)** - API reference
- **[Lua Recipes](lua-recipes.md)** - Code patterns

---

*Templates Version: 1.0*
*Last Updated: 2025-10-12*
