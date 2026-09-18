# Custom Plugin Development Guide for Neovim

**Target:** Learning Lua and Neovim ecosystem through plugin development
**Plugin Managers:** lazy.nvim, packer.nvim, vim-plug
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [2025 Plugin Trends](#2025-plugin-trends)
2. [Plugin Development Ideas](#plugin-development-ideas)
3. [Plugin Structure](#plugin-structure)
4. [Tutorial: Simple Plugin](#tutorial-simple-plugin)
5. [Tutorial: Intermediate Plugin](#tutorial-intermediate-plugin)
6. [Tutorial: Advanced Plugin](#tutorial-advanced-plugin)
7. [Plugin Manager Compatibility](#plugin-manager-compatibility)
8. [Publishing Your Plugin](#publishing-your-plugin)

---

## 2025 Plugin Trends

### Current Popular Plugins

Based on latest research, here are the most popular Neovim plugins in 2025:

#### Core Infrastructure (Most Installed)
1. **plenary.nvim** - Lua utility library (dependency for many plugins)
2. **mason.nvim** - LSP/DAP/linter package manager
3. **nvim-cmp** - Completion framework
4. **lualine.nvim** - Statusline
5. **which-key.nvim** - Keymap discovery
6. **Comment.nvim** - Smart commenting

#### Trending in 2025
1. **codecompanion.nvim** - AI chat integration (Claude, GPT, Gemini)
2. **copilot.lua** - GitHub Copilot integration
3. **trouble.nvim** - Diagnostics viewer
4. **nvim-lint** - Async linting
5. **nui.nvim** - UI component library

### Key Trends

**1. AI Integration**
- Chat interfaces for LLMs
- Code completion with AI
- Inline code generation

**2. Modern UI Components**
- Floating windows with borders
- Popup menus and selectors
- Rich diagnostic displays

**3. Async Operations**
- Non-blocking I/O
- Background processing
- Progressive loading

**4. LSP Enhancement**
- Custom handlers
- Better diagnostics
- Inlay hints customization

**5. Developer Experience**
- Quick setup functions
- Sensible defaults
- Extensive documentation

---

## Plugin Development Ideas

### Beginner Level (Learn Basics)

#### 1. **Session Manager**
**What you'll learn:** Options, autocommands, file I/O

**Features:**
- Save current session (buffers, windows, working directory)
- Restore session on startup
- List and delete old sessions
- Auto-save on exit

**APIs used:** `vim.api`, `vim.fn`, `vim.loop`, `vim.json`

---

#### 2. **Smart Buffer Switcher**
**What you'll learn:** Buffers, windows, keymaps

**Features:**
- Show buffer list in floating window
- Quick jump with single key
- Show file type icons
- Sort by most recently used

**APIs used:** `vim.api.nvim_*buf*`, `vim.api.nvim_open_win`

---

#### 3. **Project Notes**
**What you'll learn:** File operations, buffers, UI

**Features:**
- Create project-local notes
- Quick note templates
- Search through notes
- Link notes together

**APIs used:** `vim.fs`, `vim.api`, `vim.fn`

---

### Intermediate Level (Learn Advanced APIs)

#### 4. **Code Snippet Manager**
**What you'll learn:** Treesitter, text manipulation, UI

**Features:**
- Extract code snippets to library
- Insert snippets with template variables
- Organize by language and category
- Preview before insertion

**APIs used:** `vim.treesitter`, `vim.api`, floating windows

---

#### 5. **Git Blame Popup**
**What you'll learn:** External commands, async, UI

**Features:**
- Show git blame for current line
- Display in floating window
- Show commit details
- Link to remote repository

**APIs used:** `vim.loop`, `vim.system`, `vim.api`

---

#### 6. **TODO Manager**
**What you'll learn:** Treesitter queries, quickfix, UI

**Features:**
- Find all TODO/FIXME/NOTE comments
- Group by type and file
- Jump to location
- Statistics dashboard

**APIs used:** `vim.treesitter.query`, quickfix lists

---

#### 7. **Test Runner Dashboard**
**What you'll learn:** Terminal, jobs, UI

**Features:**
- Run tests with keybind
- Show results in split or float
- Navigate failures
- Re-run failed tests

**APIs used:** `vim.api.nvim_open_term`, jobs

---

### Advanced Level (Learn Complex Patterns)

#### 8. **Mini LSP Client**
**What you'll learn:** LSP protocol, RPC, handlers

**Features:**
- Custom LSP client for simple language
- Hover documentation
- Go to definition
- Diagnostics

**APIs used:** `vim.lsp.*`, RPC, JSON-RPC

---

#### 9. **Custom Debugger UI**
**What you'll learn:** DAP protocol, UI layouts, state management

**Features:**
- Debug adapter integration
- Breakpoint management
- Variable inspection
- Custom UI layout

**APIs used:** `vim.api`, DAP protocol, complex UI

---

#### 10. **Code Complexity Analyzer**
**What you'll learn:** Treesitter, metrics, visualization

**Features:**
- Calculate cyclomatic complexity
- Show complexity heatmap
- Suggest refactoring
- Track complexity over time

**APIs used:** `vim.treesitter`, virtual text, extmarks

---

#### 11. **AI Code Assistant** (Trending 2025!)
**What you'll learn:** HTTP requests, streaming, AI APIs

**Features:**
- Chat interface with LLM
- Code generation
- Inline code suggestions
- Context-aware prompts

**APIs used:** `vim.loop`, HTTP, streaming, floating windows

---

## Plugin Structure

### Standard Plugin Directory Layout

```
my-plugin.nvim/
├── lua/
│   └── my-plugin/
│       ├── init.lua          # Main entry point
│       ├── config.lua        # Configuration management
│       ├── commands.lua      # User commands
│       ├── keymaps.lua       # Keymaps
│       ├── ui/
│       │   ├── init.lua
│       │   ├── window.lua    # Window management
│       │   └── render.lua    # Rendering
│       └── utils/
│           ├── init.lua
│           ├── git.lua       # Git utilities
│           └── fs.lua        # File system utilities
├── plugin/
│   └── my-plugin.lua         # Auto-loaded on startup
├── doc/
│   └── my-plugin.txt         # Vim help documentation
├── README.md
├── LICENSE
└── .github/
    └── workflows/
        └── test.yml          # CI/CD
```

### Minimal Plugin Structure

```
my-plugin.nvim/
├── lua/
│   └── my-plugin/
│       └── init.lua
├── plugin/
│   └── my-plugin.lua
└── README.md
```

---

## Tutorial: Simple Plugin

### Project 1: Session Manager

Let's build a complete session manager plugin that saves and restores your Neovim sessions.

#### Step 1: Create Plugin Structure

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start/session-manager.nvim
cd ~/.local/share/nvim/site/pack/plugins/start/session-manager.nvim

mkdir -p lua/session-manager
mkdir -p plugin
```

#### Step 2: Main Module

**File: `lua/session-manager/init.lua`**

```lua
--- Session Manager Plugin
--- Save and restore Neovim sessions

local M = {}

-- Plugin state
local config = {
  -- Session directory
  sessions_dir = vim.fn.stdpath("data") .. "/sessions",
  -- Auto-save on exit
  auto_save = true,
  -- Auto-restore on startup
  auto_restore = false,
}

--- Setup function
--- @param opts table|nil User configuration
function M.setup(opts)
  -- Merge user config with defaults
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Create sessions directory
  vim.fn.mkdir(config.sessions_dir, "p")

  -- Setup autocommands
  if config.auto_save then
    M._setup_auto_save()
  end

  if config.auto_restore then
    M._setup_auto_restore()
  end

  -- Create user commands
  M._create_commands()
end

--- Save current session
--- @param name string|nil Session name (defaults to cwd name)
function M.save_session(name)
  name = name or M._get_default_session_name()
  local session_file = config.sessions_dir .. "/" .. name .. ".vim"

  -- Save session using Vim's mksession
  vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))

  vim.notify(
    string.format("Session saved: %s", name),
    vim.log.levels.INFO
  )
end

--- Load session
--- @param name string|nil Session name (defaults to cwd name)
function M.load_session(name)
  name = name or M._get_default_session_name()
  local session_file = config.sessions_dir .. "/" .. name .. ".vim"

  if vim.fn.filereadable(session_file) == 0 then
    vim.notify(
      string.format("Session not found: %s", name),
      vim.log.levels.ERROR
    )
    return
  end

  -- Close all buffers first
  vim.cmd("bufdo bwipeout")

  -- Load session
  vim.cmd("source " .. vim.fn.fnameescape(session_file))

  vim.notify(
    string.format("Session loaded: %s", name),
    vim.log.levels.INFO
  )
end

--- List all sessions
function M.list_sessions()
  local sessions = vim.fn.glob(config.sessions_dir .. "/*.vim", false, true)

  if #sessions == 0 then
    vim.notify("No sessions found", vim.log.levels.INFO)
    return
  end

  -- Extract session names
  local names = {}
  for _, session in ipairs(sessions) do
    local name = vim.fn.fnamemodify(session, ":t:r")
    table.insert(names, name)
  end

  -- Show in quickfix
  local items = {}
  for _, name in ipairs(names) do
    table.insert(items, {
      text = name,
      filename = config.sessions_dir .. "/" .. name .. ".vim",
    })
  end

  vim.fn.setqflist(items, "r")
  vim.cmd("copen")
  vim.notify(
    string.format("Found %d session(s)", #names),
    vim.log.levels.INFO
  )
end

--- Delete session
--- @param name string Session name
function M.delete_session(name)
  local session_file = config.sessions_dir .. "/" .. name .. ".vim"

  if vim.fn.filereadable(session_file) == 0 then
    vim.notify(
      string.format("Session not found: %s", name),
      vim.log.levels.ERROR
    )
    return
  end

  -- Confirm deletion
  local confirm = vim.fn.confirm(
    string.format("Delete session '%s'?", name),
    "&Yes\n&No",
    2
  )

  if confirm == 1 then
    vim.fn.delete(session_file)
    vim.notify(
      string.format("Session deleted: %s", name),
      vim.log.levels.INFO
    )
  end
end

--- Private: Get default session name from cwd
function M._get_default_session_name()
  local cwd = vim.fn.getcwd()
  local name = vim.fn.fnamemodify(cwd, ":t")
  return name
end

--- Private: Setup auto-save
function M._setup_auto_save()
  local group = vim.api.nvim_create_augroup("SessionManager", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.save_session()
    end,
    desc = "Auto-save session on exit",
  })
end

--- Private: Setup auto-restore
function M._setup_auto_restore()
  local group = vim.api.nvim_create_augroup("SessionManager", { clear = false })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true,
    callback = function()
      -- Only restore if no files were opened
      if vim.fn.argc() == 0 then
        M.load_session()
      end
    end,
    desc = "Auto-restore session on startup",
  })
end

--- Private: Create user commands
function M._create_commands()
  vim.api.nvim_create_user_command("SessionSave", function(opts)
    M.save_session(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = function()
      -- Return existing session names for completion
      local sessions = vim.fn.glob(config.sessions_dir .. "/*.vim", false, true)
      local names = {}
      for _, session in ipairs(sessions) do
        table.insert(names, vim.fn.fnamemodify(session, ":t:r"))
      end
      return names
    end,
    desc = "Save current session",
  })

  vim.api.nvim_create_user_command("SessionLoad", function(opts)
    M.load_session(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = function()
      local sessions = vim.fn.glob(config.sessions_dir .. "/*.vim", false, true)
      local names = {}
      for _, session in ipairs(sessions) do
        table.insert(names, vim.fn.fnamemodify(session, ":t:r"))
      end
      return names
    end,
    desc = "Load session",
  })

  vim.api.nvim_create_user_command("SessionList", function()
    M.list_sessions()
  end, {
    desc = "List all sessions",
  })

  vim.api.nvim_create_user_command("SessionDelete", function(opts)
    if opts.args == "" then
      vim.notify("Please provide a session name", vim.log.levels.ERROR)
      return
    end
    M.delete_session(opts.args)
  end, {
    nargs = 1,
    complete = function()
      local sessions = vim.fn.glob(config.sessions_dir .. "/*.vim", false, true)
      local names = {}
      for _, session in ipairs(sessions) do
        table.insert(names, vim.fn.fnamemodify(session, ":t:r"))
      end
      return names
    end,
    desc = "Delete a session",
  })
end

return M
```

#### Step 3: Auto-load File (Optional)

**File: `plugin/session-manager.lua`**

```lua
-- Auto-load plugin
-- This file runs automatically when Neovim starts

-- Prevent loading twice
if vim.g.loaded_session_manager then
  return
end
vim.g.loaded_session_manager = true

-- Setup with default configuration
-- Users can override this in their config
require("session-manager").setup()
```

#### Step 4: Installation

##### With lazy.nvim

```lua
-- In your plugins configuration
{
  dir = "~/.local/share/nvim/site/pack/plugins/start/session-manager.nvim",
  config = function()
    require("session-manager").setup({
      auto_save = true,
      auto_restore = false,
    })

    -- Add keymaps
    vim.keymap.set("n", "<leader>ss", "<cmd>SessionSave<cr>", { desc = "Save session" })
    vim.keymap.set("n", "<leader>sl", "<cmd>SessionLoad<cr>", { desc = "Load session" })
    vim.keymap.set("n", "<leader>sd", "<cmd>SessionList<cr>", { desc = "List sessions" })
  end,
}
```

##### With packer.nvim

```lua
use {
  "~/.local/share/nvim/site/pack/plugins/start/session-manager.nvim",
  config = function()
    require("session-manager").setup({
      auto_save = true,
      auto_restore = false,
    })
  end
}
```

##### With vim-plug

```vim
Plug '~/.local/share/nvim/site/pack/plugins/start/session-manager.nvim'

lua << EOF
  require("session-manager").setup({
    auto_save = true,
    auto_restore = false,
  })
EOF
```

#### Step 5: Usage

```vim
" Save session
:SessionSave
:SessionSave my-project

" Load session
:SessionLoad
:SessionLoad my-project

" List sessions
:SessionList

" Delete session
:SessionDelete my-project
```

---

## Tutorial: Intermediate Plugin

### Project 2: TODO Comment Finder

A plugin that finds and manages TODO comments in your project.

#### File: `lua/todo-finder/init.lua`

```lua
--- TODO Finder Plugin
--- Find and manage TODO/FIXME/NOTE comments

local M = {}

local config = {
  -- Keywords to search for
  keywords = { "TODO", "FIXME", "NOTE", "HACK", "WARNING" },
  -- Highlight groups for each keyword
  highlights = {
    TODO = "DiagnosticInfo",
    FIXME = "DiagnosticError",
    NOTE = "DiagnosticHint",
    HACK = "DiagnosticWarn",
    WARNING = "DiagnosticWarn",
  },
}

--- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  M._create_commands()
  M._setup_highlights()
end

--- Find all TODOs in project
function M.find_todos()
  local todos = {}

  -- Build ripgrep command
  local pattern = "\\b(" .. table.concat(config.keywords, "|") .. ")\\b"
  local cmd = {
    "rg",
    "--vimgrep",
    "--no-heading",
    "--smart-case",
    pattern,
  }

  -- Execute ripgrep
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("No TODOs found", vim.log.levels.INFO)
    return
  end

  -- Parse results
  for line in result:gmatch("[^\n]+") do
    local file, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.+)$")
    if file then
      -- Extract keyword
      local keyword = nil
      for _, kw in ipairs(config.keywords) do
        if text:match(kw) then
          keyword = kw
          break
        end
      end

      table.insert(todos, {
        filename = file,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = vim.trim(text),
        type = keyword or "TODO",
      })
    end
  end

  -- Show in quickfix
  vim.fn.setqflist({}, "r", {
    title = "TODO Comments",
    items = todos,
  })

  vim.cmd("copen")
  vim.notify(
    string.format("Found %d TODO comment(s)", #todos),
    vim.log.levels.INFO
  )

  -- Apply highlighting
  M._highlight_quickfix()
end

--- Show TODO dashboard
function M.show_dashboard()
  -- Get all todos
  local cmd = {
    "rg",
    "--vimgrep",
    "--no-heading",
    "--smart-case",
    "\\b(" .. table.concat(config.keywords, "|") .. ")\\b",
  }

  local result = vim.fn.system(cmd)

  -- Count by type
  local counts = {}
  for _, kw in ipairs(config.keywords) do
    counts[kw] = 0
  end

  for line in result:gmatch("[^\n]+") do
    for _, kw in ipairs(config.keywords) do
      if line:match(kw) then
        counts[kw] = counts[kw] + 1
        break
      end
    end
  end

  -- Create dashboard buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    "TODO Dashboard",
    "=============",
    "",
  }

  local total = 0
  for _, kw in ipairs(config.keywords) do
    local count = counts[kw]
    total = total + count
    table.insert(lines, string.format("%s: %d", kw, count))
  end

  table.insert(lines, "")
  table.insert(lines, string.format("Total: %d", total))
  table.insert(lines, "")
  table.insert(lines, "Press <CR> to find all TODOs")
  table.insert(lines, "Press q to close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  -- Create floating window
  local width = 40
  local height = #lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " TODO Dashboard ",
    title_pos = "center",
  })

  -- Keymaps
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  vim.keymap.set("n", "<CR>", function()
    vim.api.nvim_win_close(win, true)
    M.find_todos()
  end, { buffer = buf })
end

--- Private: Setup highlights
function M._setup_highlights()
  for keyword, hl_group in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, "TodoFinder" .. keyword, {
      link = hl_group
    })
  end
end

--- Private: Highlight quickfix entries
function M._highlight_quickfix()
  local qflist = vim.fn.getqflist()

  for i, item in ipairs(qflist) do
    local keyword = item.type
    if keyword then
      -- This is simplified - you'd use extmarks in real implementation
      -- vim.api.nvim_buf_add_highlight(...)
    end
  end
end

--- Private: Create commands
function M._create_commands()
  vim.api.nvim_create_user_command("TodoFind", function()
    M.find_todos()
  end, { desc = "Find all TODO comments" })

  vim.api.nvim_create_user_command("TodoDashboard", function()
    M.show_dashboard()
  end, { desc = "Show TODO dashboard" })
end

return M
```

#### Installation and Usage

```lua
-- lazy.nvim
{
  dir = "path/to/todo-finder.nvim",
  config = function()
    require("todo-finder").setup({
      keywords = { "TODO", "FIXME", "NOTE", "HACK" },
    })

    vim.keymap.set("n", "<leader>td", "<cmd>TodoDashboard<cr>", { desc = "TODO Dashboard" })
    vim.keymap.set("n", "<leader>tf", "<cmd>TodoFind<cr>", { desc = "Find TODOs" })
  end,
}
```

---

## Tutorial: Advanced Plugin

### Project 3: AI Code Assistant

A plugin that integrates with AI APIs (OpenAI, Anthropic) for code assistance.

**Note:** This is a simplified example. Full implementation would need proper error handling, streaming, and more features.

#### File: `lua/ai-assistant/init.lua`

```lua
--- AI Code Assistant Plugin
--- Chat with AI and get code suggestions

local M = {}

local config = {
  provider = "openai",  -- or "anthropic"
  api_key = nil,  -- Set via environment variable
  model = "gpt-4",
  max_tokens = 1000,
  temperature = 0.7,
}

--- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Get API key from environment
  if not config.api_key then
    config.api_key = vim.env.OPENAI_API_KEY or vim.env.ANTHROPIC_API_KEY
  end

  if not config.api_key then
    vim.notify(
      "AI Assistant: No API key found. Set OPENAI_API_KEY or ANTHROPIC_API_KEY",
      vim.log.levels.WARN
    )
  end

  M._create_commands()
end

--- Open chat interface
function M.open_chat()
  -- Create chat buffer
  local buf = vim.api.nvim_create_buf(false, true)

  local lines = {
    "# AI Code Assistant",
    "",
    "Type your question below and press <C-s> to send.",
    "Press q to close.",
    "",
    "---",
    "",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  -- Create window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " AI Assistant ",
    title_pos = "center",
  })

  -- Setup keymaps
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  vim.keymap.set("n", "<C-s>", function()
    M._send_message(buf)
  end, { buffer = buf })

  vim.keymap.set("i", "<C-s>", function()
    vim.cmd("stopinsert")
    M._send_message(buf)
  end, { buffer = buf })

  -- Move to end
  vim.cmd("normal! G")
end

--- Ask AI about selected code
function M.explain_code()
  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local code = table.concat(lines, "\n")

  -- Create prompt
  local prompt = string.format(
    "Explain the following code:\n\n```\n%s\n```",
    code
  )

  -- Send to AI
  M._query_ai(prompt, function(response)
    -- Show in floating window
    M._show_response(response)
  end)
end

--- Private: Send message from chat buffer
function M._send_message(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Find user message (after "---")
  local message_start = nil
  for i, line in ipairs(lines) do
    if line == "---" then
      message_start = i + 1
      break
    end
  end

  if not message_start then
    return
  end

  local message_lines = vim.list_slice(lines, message_start)
  local message = table.concat(message_lines, "\n")
  message = vim.trim(message)

  if message == "" then
    return
  end

  -- Show loading indicator
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
    "",
    "Thinking...",
  })

  -- Query AI
  M._query_ai(message, function(response)
    -- Remove loading indicator
    local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_buf_set_lines(buf, #current_lines - 1, -1, false, {})

    -- Add response
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
      "",
      "## AI Response:",
      "",
      response,
      "",
      "---",
      "",
    })

    -- Scroll to bottom
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
  end)
end

--- Private: Query AI API
function M._query_ai(prompt, callback)
  if not config.api_key then
    vim.notify("No API key configured", vim.log.levels.ERROR)
    return
  end

  local url = "https://api.openai.com/v1/chat/completions"
  local data = vim.json.encode({
    model = config.model,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
    max_tokens = config.max_tokens,
    temperature = config.temperature,
  })

  -- Use curl (simplified - should use vim.loop for async)
  local curl_cmd = string.format(
    'curl -s -X POST %s -H "Content-Type: application/json" -H "Authorization: Bearer %s" -d %s',
    url,
    config.api_key,
    vim.fn.shellescape(data)
  )

  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, output)
      if output then
        local response_text = table.concat(output, "\n")
        local ok, response = pcall(vim.json.decode, response_text)

        if ok and response.choices and response.choices[1] then
          local message = response.choices[1].message.content
          callback(message)
        else
          vim.notify("Failed to parse AI response", vim.log.levels.ERROR)
        end
      end
    end,
    on_stderr = function(_, err)
      if err and #err > 0 then
        vim.notify("AI API error: " .. table.concat(err, "\n"), vim.log.levels.ERROR)
      end
    end,
  })
end

--- Private: Show response in floating window
function M._show_response(text)
  local buf = vim.api.nvim_create_buf(false, true)

  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " AI Response ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

--- Private: Create commands
function M._create_commands()
  vim.api.nvim_create_user_command("AIChat", function()
    M.open_chat()
  end, { desc = "Open AI chat interface" })

  vim.api.nvim_create_user_command("AIExplain", function()
    M.explain_code()
  end, {
    range = true,
    desc = "Explain selected code",
  })
end

return M
```

---

## Plugin Manager Compatibility

### Making Your Plugin Compatible with All Managers

#### lazy.nvim Support

```lua
-- Your plugin should work with lazy-loading
-- Mark which features trigger loading

-- File: lua/my-plugin/init.lua
local M = {}

M.setup = function(opts)
  -- Configuration
end

-- Expose commands for lazy-loading
M.commands = {
  MyCommand = function() --[[ ... ]] end,
}

return M
```

**User configuration:**

```lua
{
  "username/my-plugin.nvim",
  cmd = { "MyCommand" },  -- Lazy load on command
  keys = {  -- Lazy load on keymap
    { "<leader>mp", "<cmd>MyCommand<cr>", desc = "My Plugin" },
  },
  config = function()
    require("my-plugin").setup()
  end,
}
```

#### packer.nvim Support

```lua
use {
  "username/my-plugin.nvim",
  config = function()
    require("my-plugin").setup()
  end,
}
```

#### vim-plug Support

```vim
Plug 'username/my-plugin.nvim'

lua << EOF
  require("my-plugin").setup()
EOF
```

### Best Practices for Compatibility

1. **No Auto-initialization:** Don't run code automatically in `init.lua`
2. **Provide setup() function:** Let users configure your plugin
3. **Use plugin/ for optional auto-loading:** Only for truly essential features
4. **Document lazy-loading:** Show users which features trigger loading
5. **Check dependencies:** Use `pcall()` for optional dependencies

---

## Publishing Your Plugin

### 1. Prepare Repository

```bash
# Create repository structure
git init
git add .
git commit -m "Initial commit"

# Add remote
git remote add origin https://github.com/username/my-plugin.nvim.git
git push -u origin main
```

### 2. Write README.md

Include:
- Description
- Features
- Installation for all plugin managers
- Configuration examples
- Usage examples
- API documentation

### 3. Add Documentation

Create `doc/my-plugin.txt` for Vim help:

```
*my-plugin.txt*  Description of your plugin

==============================================================================
CONTENTS                                                  *my-plugin-contents*

1. Introduction ............................... |my-plugin-introduction|
2. Installation ............................... |my-plugin-installation|
3. Configuration .............................. |my-plugin-configuration|
4. Commands ................................... |my-plugin-commands|
5. API ........................................ |my-plugin-api|

==============================================================================
INTRODUCTION                                          *my-plugin-introduction*

Your plugin description here.

==============================================================================
INSTALLATION                                          *my-plugin-installation*

lazy.nvim: >
  {
    "username/my-plugin.nvim",
    config = function()
      require("my-plugin").setup()
    end
  }
<
```

### 4. Test

Create `tests/` directory:

```lua
-- tests/init_spec.lua
describe("my-plugin", function()
  it("loads without errors", function()
    local ok = pcall(require, "my-plugin")
    assert.is_true(ok)
  end)

  it("has setup function", function()
    local plugin = require("my-plugin")
    assert.is_function(plugin.setup)
  end)
end)
```

### 5. Submit to Plugin Directories

- **awesome-neovim:** https://github.com/rockerBOO/awesome-neovim
- **neovimcraft:** https://neovimcraft.com
- **dotfyle:** https://dotfyle.com

---

## Learning Resources

### Documentation

- **:help write-plugin** - Vim plugin guide
- **:help lua-guide** - Lua in Neovim
- **:help api** - Neovim API

### Example Plugins to Study

**Simple:**
- Comment.nvim - Good example of treesitter integration
- which-key.nvim - Clean UI patterns

**Intermediate:**
- trouble.nvim - Complex UI with lists
- gitsigns.nvim - External command integration

**Advanced:**
- telescope.nvim - Picker framework
- nvim-cmp - Completion engine

---

## Next Steps

1. **Choose a project** from the ideas above
2. **Start small** with beginner projects
3. **Read existing plugins** for patterns
4. **Share your work** on GitHub
5. **Get feedback** from community

Good luck with your plugin development journey! 🚀

---

*Guide Version: 1.0*
*Last Updated: 2025-10-12*
