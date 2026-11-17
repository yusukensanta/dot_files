-- Go templates (lua/plugins/lang/go.lua installs the gotmpl parser).
vim.filetype.add({
  extension = { gotmpl = "gotmpl" },
  pattern = { [".*%.tmpl"] = "gotmpl" },
})
