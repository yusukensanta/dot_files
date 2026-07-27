-- plantuml-previewer.vim — live PlantUML diagram preview in browser
-- Requires: java + plantuml.jar installed locally (renders offline).
-- Set PLANTUML_JAR env var or g:plantuml_previewer_plantuml_jar_path to a local jar
-- to guarantee offline rendering (avoids any potential fallback to plantuml.com).
return {
  {
    "weirongxu/plantuml-previewer.vim",
    dependencies = {
      "tyru/open-browser.vim",
      "aklt/plantuml-syntax",
    },
    ft = { "plantuml" },
    init = function()
      -- Force local JAR rendering. Check common install locations.
      local jar_candidates = {
        vim.fn.expand("~/.local/share/plantuml/plantuml.jar"),
        "/usr/share/plantuml/plantuml.jar",
        "/usr/local/share/plantuml/plantuml.jar",
        vim.fn.expand("~/plantuml.jar"),
      }
      for _, path in ipairs(jar_candidates) do
        if vim.fn.filereadable(path) == 1 then
          vim.g.plantuml_previewer_plantuml_jar_path = path
          break
        end
      end
      if not vim.g.plantuml_previewer_plantuml_jar_path then
        -- Defer the notice to actually opening a plantuml buffer instead of
        -- firing on every Neovim startup (this init() always runs at
        -- startup regardless of the ft= lazy-load trigger).
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "plantuml",
          once = true,
          callback = function()
            vim.notify(
              "plantuml.jar not found. Set g:plantuml_previewer_plantuml_jar_path to enable local rendering.",
              vim.log.levels.WARN
            )
          end,
        })
      end
    end,
  },
}
