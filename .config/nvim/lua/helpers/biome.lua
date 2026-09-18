-- Shared biome binary resolution: project-local > global > pinned npx
-- fallback. Used by both config/format.lua (BufWritePre pipeline) and
-- plugins/conform.lua (biome formatter definition) so the two can't drift
-- out of sync with each other.
--
-- Missing guard, by design of how this resolution works: "project-local"
-- means whatever binary sits at node_modules/.bin/biome, found by walking up
-- from the current file toward $HOME or /. Opening any repo — including an
-- untrusted, freshly-cloned one — and saving a JS/TS/JSON file executes that
-- binary with no confirmation prompt. There is no workspace-trust gate here;
-- if that matters for your workflow, inspect node_modules/.bin/biome (and
-- its package's install scripts) before saving in a repo you don't already
-- trust.
local M = {}

local NPX_ARGS = { "--yes", "@biomejs/biome@2.3.8" }

-- The base command: an absolute path to the project-local binary, "biome"
-- if one is on PATH, or "npx" as a last resort (pair with npx_bootstrap_args()).
function M.resolve_command()
  local project_biome = vim.fn.findfile("node_modules/.bin/biome", ".;")
  if project_biome ~= "" then
    return vim.fn.fnamemodify(project_biome, ":p")
  end
  if vim.fn.executable("biome") == 1 then
    return "biome"
  end
  return "npx"
end

-- Whether resolve_command() found a real local/global biome, as opposed to
-- falling back to npx.
function M.has_local()
  return M.resolve_command() ~= "npx"
end

-- npx args to prepend before biome's own subcommand/args when
-- resolve_command() fell back to "npx". Returns a fresh table each call so
-- callers can vim.list_extend() it without mutating the shared pin.
function M.npx_bootstrap_args()
  return vim.deepcopy(NPX_ARGS)
end

return M
