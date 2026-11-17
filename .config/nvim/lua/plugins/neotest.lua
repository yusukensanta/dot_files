-- Test-running core, shared by every language. It names no language
-- itself: each lua/plugins/lang/<language>.lua adds its adapter plugin as a
-- dependency and its adapter to `opts.adapters` (adapter module name ->
-- options; `{}` uses the adapter as is). Loaded on the first test keymap.
-- Scala has no adapter: lang/scala.lua maps the same keys to Metals' Test
-- Explorer in Scala buffers.
local function neotest(fn)
  return function()
    fn(require("neotest"))
  end
end

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      ---@type table<string, table|false>
      adapters = {},
      output = { open_on_run = true },
      summary = { animated = true },
    },
    config = function(_, opts)
      local adapters = {}
      for name, adapter_opts in pairs(opts.adapters) do
        if adapter_opts then
          local adapter = require(name)
          -- Adapters such as neotest-python are factories taking options;
          -- others (rustaceanvim.neotest) are the adapter itself.
          local mt = getmetatable(adapter)
          if next(adapter_opts) or (mt and mt.__call and not adapter.name) then
            adapter = adapter(adapter_opts)
          end
          adapters[#adapters + 1] = adapter
        end
      end
      opts.adapters = adapters
      require("neotest").setup(opts)
    end,
    keys = {
      {
        "<leader>nr",
        neotest(function(n)
          n.run.run()
        end),
        desc = "Test - Run nearest",
      },
      {
        "<leader>nf",
        neotest(function(n)
          n.run.run(vim.fn.expand("%"))
        end),
        desc = "Test - Run file",
      },
      {
        "<leader>ns",
        neotest(function(n)
          n.summary.toggle()
        end),
        desc = "Test - Toggle summary",
      },
      {
        "<leader>no",
        neotest(function(n)
          n.output.open({ enter = true })
        end),
        desc = "Test - Open output",
      },
      {
        "<leader>nd",
        neotest(function(n)
          n.run.run({ strategy = "dap" })
        end),
        desc = "Test - Debug nearest",
      },
      {
        "[t",
        neotest(function(n)
          n.jump.prev({ status = "failed" })
        end),
        desc = "Test - Jump prev failed",
      },
      {
        "]t",
        neotest(function(n)
          n.jump.next({ status = "failed" })
        end),
        desc = "Test - Jump next failed",
      },
    },
  },
}
