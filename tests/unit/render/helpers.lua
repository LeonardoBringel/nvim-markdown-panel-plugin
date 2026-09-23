-- Shared helpers for render specs. Not a spec file: plenary only runs *_spec.lua.
local M = {}

local function end_key(end_col)
  return end_col == -1 and math.huge or end_col
end

--- Sorts highlights by (row, col, end_col, group) so specs can compare exact
--- lists without depending on the order the renderer emits them in.
---@param highlights mdp.Highlight[]
---@return mdp.Highlight[]
function M.sorted(highlights)
  local copy = vim.deepcopy(highlights)
  table.sort(copy, function(a, b)
    if a.row ~= b.row then
      return a.row < b.row
    end
    if a.col ~= b.col then
      return a.col < b.col
    end
    if a.end_col ~= b.end_col then
      return end_key(a.end_col) < end_key(b.end_col)
    end
    return a.group < b.group
  end)
  return copy
end

--- Renders `lines` and returns the result with highlights sorted.
---@param lines string[]
---@param width integer|nil
---@return mdp.Rendered
function M.render(lines, width)
  local rendered, err = require("markdown_panel.render").render(lines, { width = width or 80 })
  assert(rendered, err)
  return { lines = rendered.lines, highlights = M.sorted(rendered.highlights) }
end

--- Builds an expected highlight. `group` is the suffix after "MarkdownPanel".
---@return mdp.Highlight
function M.hl(row, col, end_col, group)
  return { row = row, col = col, end_col = end_col, group = "MarkdownPanel" .. group }
end

return M
