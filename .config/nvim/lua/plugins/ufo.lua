-- nvim-ufo — smart code folding via LSP + treesitter
-- Collapses entire functions/classes/imports while showing a count of hidden lines.
-- zK peeks at folded content in a floating window without opening the fold.
-- zR / zM are standard Vim fold keys, unused in your config.
return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    opts = {
      -- Prefer LSP fold ranges; fall back to indent-based for unsupported languages
      provider_selector = function(bufnr, filetype, buftype)
        return { "lsp", "indent" }
      end,
      -- Show a summary of hidden lines when a fold is closed
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (" 󰁂 %d lines"):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end,
    },
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,                     desc = "UFO: open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end,                    desc = "UFO: close all folds" },
      { "zK", function() require("ufo").peekFoldedLinesUnderCursor() end,       desc = "UFO: peek fold content" },
    },
    init = function()
      -- "auto" only shows the fold column when there are actually foldable lines,
      -- avoiding a permanently blank left-edge column (which looked like corruption).
      -- foldlevel/foldlevelstart are already set in options.lua so not duplicated here.
      vim.o.foldcolumn = "auto"
    end,
  },
}
