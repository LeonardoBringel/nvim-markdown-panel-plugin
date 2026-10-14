local M = {}

---@param opts table|nil
function M.setup(opts)
  require("markdown_panel.config").setup(opts)
end

---Opens the preview of `bufnr` (default: current buffer).
---@param bufnr integer|nil
function M.open(bufnr)
  if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("markdown-panel: requires Neovim >= 0.10", vim.log.levels.ERROR)
    return
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "markdown" then
    vim.notify("markdown-panel: current buffer is not markdown", vim.log.levels.WARN)
    return
  end

  local window = require("markdown_panel.window")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local rendered, err = require("markdown_panel.render").render(lines, { width = window.dimensions().width })
  if not rendered then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local blank = vim.iter(lines):all(function(line)
    return not line:find("%S")
  end)
  if blank then
    rendered = { lines = { "(empty document)" }, highlights = {}, line_map = {} }
  end

  require("markdown_panel.highlights").setup()
  window.open(rendered.lines, rendered.highlights)
end

function M.close()
  require("markdown_panel.window").close()
end

return M
