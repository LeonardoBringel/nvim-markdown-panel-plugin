-- GFM pipe tables (MDP-34, MDP-35, MDP-47): box-drawing borders, columns as
-- wide as their widest rendered cell (display width) plus 1 space each side,
-- alignment from the delimiter row. Each source row is replaced by its own
-- table lines, so container prefixes (quote bar, list marker) follow the rows.
local inline = require("markdown_panel.render.inline")

local M = {}

local BORDER = "MarkdownPanelTableBorder"
local HEADER = "MarkdownPanelTableHeader"
local BAR = "│"

---@class mdp.Cell
---@field text string
---@field hl mdp.LineHighlight[]
---@field width integer

---@type mdp.Cell
local EMPTY = { text = "", hl = {}, width = 0 }

--- Renders a cell through the inline pass. The cell range ends with the blanks
--- before the next `|`: they are not part of the text.
---@param node TSNode
---@param ctx mdp.Ctx
---@return mdp.Cell
local function render_cell(node, ctx)
  local r, sc, _, ec = node:range()
  local text, hl = inline.apply(ctx.lines[r + 1]:sub(1, ec), r, sc, ctx.edits_by_row[r] or {})
  text = text:gsub("%s+$", "")
  return { text = text, hl = hl, width = vim.fn.strdisplaywidth(text) }
end

--- `:-:` has both align nodes, `--:` only the right one.
---@param node TSNode pipe_table_delimiter_cell
---@return "left"|"center"|"right"
local function align_of(node)
  local left, right = false, false
  for child in node:iter_children() do
    left = left or child:type() == "pipe_table_align_left"
    right = right or child:type() == "pipe_table_align_right"
  end
  return right and (left and "center" or "right") or "left"
end

---@param widths integer[]
---@param l string
---@param m string
---@param r string
---@return {text: string, hl: mdp.LineHighlight[]}
local function rule(widths, l, m, r)
  local parts = {}
  for i, w in ipairs(widths) do
    parts[i] = string.rep("─", w + 2)
  end
  local text = l .. table.concat(parts, m) .. r
  return { text = text, hl = { { col = 0, end_col = #text, group = BORDER } } }
end

--- A row of cells between `│`. Cells beyond the column count are ignored,
--- missing ones are empty (GFM).
---@param cells mdp.Cell[]
---@param widths integer[]
---@param aligns string[]
---@param header boolean
---@return {text: string, hl: mdp.LineHighlight[]}
local function cells_line(cells, widths, aligns, header)
  local text = BAR
  local hl = { { col = 0, end_col = #BAR, group = BORDER } }
  for i, w in ipairs(widths) do
    local cell = cells[i] or EMPTY
    local extra = w - cell.width
    local left = aligns[i] == "right" and extra or aligns[i] == "center" and math.floor(extra / 2) or 0
    local start = #text + 1 + left
    for _, h in ipairs(cell.hl) do
      hl[#hl + 1] = { col = start + h.col, end_col = start + h.end_col, group = h.group }
    end
    if header then
      hl[#hl + 1] = { col = start, end_col = start + #cell.text, group = HEADER }
    end
    text = text .. string.rep(" ", 1 + left) .. cell.text .. string.rep(" ", extra - left + 1)
    hl[#hl + 1] = { col = #text, end_col = #text + #BAR, group = BORDER }
    text = text .. BAR
  end
  return { text = text, hl = hl }
end

---@type table<string, mdp.Handler>
M.handlers = {}

function M.handlers.pipe_table(node, ctx)
  local rows, aligns = {}, {}
  local delimiter_row = 0 -- every pipe_table has one: set below
  for child in node:iter_children() do
    local t = child:type()
    if t == "pipe_table_delimiter_row" then
      delimiter_row = child:range()
      for cell in child:iter_children() do
        if cell:type() == "pipe_table_delimiter_cell" then
          aligns[#aligns + 1] = align_of(cell)
        end
      end
    elseif t == "pipe_table_header" or t == "pipe_table_row" then
      local cells = {}
      for cell in child:iter_children() do
        if cell:type() == "pipe_table_cell" then
          cells[#cells + 1] = render_cell(cell, ctx)
        end
      end
      rows[#rows + 1] = { r = child:range(), cells = cells }
    end
  end

  local widths = {}
  for i = 1, #aligns do
    widths[i] = 0
    for _, row in ipairs(rows) do
      widths[i] = math.max(widths[i], (row.cells[i] or EMPTY).width)
    end
  end

  -- Every line of a replaced row gets that row's prefix: the first row carries
  -- only the top border, so a list marker is shown once.
  local header = rows[1]
  ctx:row(header.r).replace = { rule(widths, "┌", "┬", "┐") }
  local last = ctx:row(delimiter_row)
  last.replace = { cells_line(header.cells, widths, aligns, true), rule(widths, "├", "┼", "┤") }
  for i = 2, #rows do
    last = ctx:row(rows[i].r)
    last.replace = { cells_line(rows[i].cells, widths, aligns, false) }
  end
  table.insert(last.replace, rule(widths, "└", "┴", "┘"))
end

return M
