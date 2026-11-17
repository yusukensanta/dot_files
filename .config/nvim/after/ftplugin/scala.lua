-- Scala (tooling: lua/plugins/lang/scala.lua).
-- Metals formats on save (scalafmt); its first format in a session takes
-- longer than the 500ms other formatters get.
vim.b.format_timeout_ms = 3000
