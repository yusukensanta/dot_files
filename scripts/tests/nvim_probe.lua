-- Driven by test_nvim_config.sh: opens $PROBE_FILE in headless Neovim,
-- waits until the language servers named in $PROBE_CLIENTS (comma list)
-- attach, saves the file (running format-on-save), and writes what it saw
-- as JSON to $PROBE_OUT.
local out = { notifications = {}, prompts = {} }
vim.notify = function(msg, level)
  table.insert(out.notifications, { level = level, msg = tostring(msg) })
end
-- Headless, the default picker waits on stdin forever (e.g. Metals asking
-- to import a build). Record the question and cancel it.
vim.ui.select = function(_, opts, on_choice)
  table.insert(out.prompts, tostring(opts and opts.prompt))
  on_choice(nil, nil)
end

vim.cmd.edit(os.getenv("PROBE_FILE"))
local buf = vim.api.nvim_get_current_buf()
-- Where the cursor landed on open (after the cursor-restore autocmd).
out.cursor_line = vim.api.nvim_win_get_cursor(0)[1]

local function client_names()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    names[#names + 1] = c.name
  end
  table.sort(names)
  return names
end

local want = vim.split(os.getenv("PROBE_CLIENTS") or "", ",", { trimempty = true })
local wait_ms = tonumber(os.getenv("PROBE_WAIT_MS") or "20000")
vim.wait(wait_ms, function()
  local have = client_names()
  for _, name in ipairs(want) do
    if not vim.tbl_contains(have, name) then
      return false
    end
  end
  return true
end, 100)
-- Give the servers a moment to publish diagnostics.
vim.wait(tonumber(os.getenv("PROBE_SETTLE_MS") or "1500"), function()
  return false
end, 100)

out.clients = client_names()
out.filetype = vim.bo[buf].filetype
out.shiftwidth = vim.bo[buf].shiftwidth
out.expandtab = vim.bo[buf].expandtab
out.colorcolumn = vim.wo.colorcolumn
out.spell = vim.wo.spell
out.format_timeout_ms = vim.b[buf].format_timeout_ms or vim.NIL
out.treesitter = vim.treesitter.highlighter.active[buf] ~= nil

local ok, conform = pcall(require, "conform")
out.formatters = {}
if ok then
  for _, f in ipairs(conform.list_formatters_to_run(buf)) do
    out.formatters[#out.formatters + 1] = f.name
  end
end

out.diagnostic_sources = {}
for _, d in ipairs(vim.diagnostic.get(buf)) do
  if d.source and not vim.tbl_contains(out.diagnostic_sources, d.source) then
    out.diagnostic_sources[#out.diagnostic_sources + 1] = d.source
  end
end

if os.getenv("PROBE_SAVE") == "1" then
  vim.cmd("silent write")
  vim.wait(300, function()
    return false
  end, 50)
end

-- Debug adapters registered so far (only once a language loaded nvim-dap).
out.dap_adapters = {}
if package.loaded["dap"] then
  out.dap_adapters = vim.tbl_keys(require("dap").adapters)
  table.sort(out.dap_adapters)
end

-- With PROBE_NEOTEST=1: load neotest (as its first keymap would) and list
-- the adapters it was set up with.
if os.getenv("PROBE_NEOTEST") == "1" then
  require("lazy").load({ plugins = { "neotest" } })
  out.neotest_adapters = {}
  for _, adapter in ipairs(require("neotest.config").adapters) do
    out.neotest_adapters[#out.neotest_adapters + 1] = adapter.name
  end
  table.sort(out.neotest_adapters)
end

-- With PROBE_KEYMAPS: what each key in the list below is mapped to in this
-- buffer, after the VeryLazy plugins load ("" when it is not mapped).
-- Neovim's own default mappings report their own rhs/desc.
if os.getenv("PROBE_KEYMAPS") == "1" then
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
  vim.wait(1000, function()
    return false
  end, 100)
  local keys = {
    { "s", "<" }, { "s", ">" }, { "s", "," },
    { "x", "<" }, { "x", "," },
    { "n", "<Esc>" }, { "n", "<C-T>" }, { "n", "<C-N>" }, { "n", "<C-P>" }, { "n", "L" },
    { "i", "<M-l>" },
    { "n", "]t" }, { "n", "[t" }, { "n", "]T" }, { "n", "[T" },
    { "n", "]n" }, { "n", "[n" }, { "n", "]b" }, { "n", "[b" },
    { "n", "]]" }, { "n", "[[" }, { "n", "<M-n>" },
    { "n", ",l" }, { "n", ",L" }, { "n", ",lf" }, { "n", ",ds" }, { "n", ",dd" }, { "n", ",ux" },
    { "n", ",ca" }, { "n", ",gx" }, { "n", ",gxl" }, { "n", ",hu" },
    { "x", ",hs" }, { "x", ",cf" }, { "x", "<Space>ca" },
  }
  out.maps = {}
  for _, k in ipairs(keys) do
    local m = vim.fn.maparg(k[2], k[1], false, true)
    out.maps[k[1] .. " " .. k[2]] = (m.desc or m.rhs or (m.callback and "<callback>") or "")
  end
end

out.loaded = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  if plugin._.loaded then
    out.loaded[#out.loaded + 1] = name
  end
end
table.sort(out.loaded)

-- With PROBE_CURSOR_TO: leave the buffer with the cursor on that line, so
-- the ShaDa file written on exit remembers it as the buffer's '" mark.
local cursor_to = tonumber(os.getenv("PROBE_CURSOR_TO") or "")
if cursor_to then
  vim.api.nvim_win_set_cursor(0, { cursor_to, 0 })
  vim.cmd("silent! enew!")
end

local f = assert(io.open(os.getenv("PROBE_OUT"), "w"))
f:write(vim.json.encode(out))
f:close()
vim.cmd("qa!")
