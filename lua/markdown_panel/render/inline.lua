-- Inline pass over the markdown_inline trees: edits in SOURCE coordinates,
-- then applied line by line (clipped) to produce output text + highlights.

---@class mdp.Edit
---@field kind "hide"|"style"|"replace"
---@field row integer
---@field col integer
---@field end_row integer
---@field end_col integer
---@field group string|nil   style / replace
---@field text string|nil    replace

local M = {}

local STYLE = {
  strong_emphasis = "MarkdownPanelBold",
  emphasis = "MarkdownPanelItalic",
  strikethrough = "MarkdownPanelStrike",
}

---@param kind "hide"|"style"
---@param node TSNode
---@param group string|nil
---@return mdp.Edit
local function edit(kind, node, group)
  local sr, sc, er, ec = node:range()
  return { kind = kind, row = sr, col = sc, end_row = er, end_col = ec, group = group }
end

--- Per node type: appends edits; returns true when children must not be visited.
---@type table<string, fun(node: TSNode, edits: mdp.Edit[]): boolean|nil>
local collectors = {}

for node_type, group in pairs(STYLE) do
  collectors[node_type] = function(node, edits)
    edits[#edits + 1] = edit("style", node, group)
  end
end

collectors.emphasis_delimiter = function(node, edits)
  edits[#edits + 1] = edit("hide", node)
end

collectors.code_span = function(node, edits)
  edits[#edits + 1] = edit("style", node, "MarkdownPanelCode")
  for child in node:iter_children() do
    if child:type() == "code_span_delimiter" then
      edits[#edits + 1] = edit("hide", child)
    end
  end
  return true
end

collectors.backslash_escape = function(node, edits)
  local sr, sc = node:range()
  edits[#edits + 1] = { kind = "hide", row = sr, col = sc, end_row = sr, end_col = sc + 1 }
end

---@param node TSNode
---@param edits mdp.Edit[]
local function visit(node, edits)
  local collector = collectors[node:type()]
  if collector and collector(node, edits) then
    return
  end
  for child in node:iter_children() do
    visit(child, edits)
  end
end

--- Collects the edits of every markdown_inline tree.
---@param trees TSTree[]
---@return mdp.Edit[]
function M.collect(trees)
  local edits = {}
  for _, tree in ipairs(trees) do
    visit(tree:root(), edits)
  end
  return edits
end

--- Applies the edits touching source row `row` to `line` from byte `col_start` on.
--- Returns the output text and highlights with columns relative to that text.
---@param line string
---@param row integer
---@param col_start integer
---@param edits mdp.Edit[]
---@return string, mdp.LineHighlight[]
function M.apply(line, row, col_start, edits)
  local hidden, styles = {}, {}
  for _, e in ipairs(edits) do
    if e.row <= row and row <= e.end_row then
      local c1 = math.max(e.row == row and e.col or 0, col_start)
      local c2 = math.min(e.end_row == row and e.end_col or #line, #line)
      if c1 < c2 then
        if e.kind == "hide" then
          for c = c1, c2 - 1 do
            hidden[c] = true
          end
        else
          styles[#styles + 1] = { c1, c2, e.group }
        end
      end
    end
  end

  -- out_col[c]: output column of source column c.
  local parts, out_col, len = {}, {}, 0
  for c = col_start, #line - 1 do
    out_col[c] = len
    if not hidden[c] then
      parts[#parts + 1] = line:sub(c + 1, c + 1)
      len = len + 1
    end
  end
  out_col[#line] = len

  local highlights, seen = {}, {}
  for _, s in ipairs(styles) do
    local col, end_col = out_col[s[1]], out_col[s[2]]
    local key = col .. ":" .. end_col .. ":" .. s[3]
    -- Nested nodes of the same kind (`~~x~~`) must not stack the same group.
    if end_col > col and not seen[key] then
      seen[key] = true
      highlights[#highlights + 1] = { col = col, end_col = end_col, group = s[3] }
    end
  end
  table.sort(highlights, function(a, b)
    if a.col ~= b.col then
      return a.col < b.col
    end
    if a.end_col ~= b.end_col then
      return a.end_col < b.end_col
    end
    return a.group < b.group
  end)
  return table.concat(parts), highlights
end

return M
