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

---@param kind "hide"|"style"|"replace"
---@param node TSNode
---@param group string|nil
---@return mdp.Edit
local function edit(kind, node, group)
  local sr, sc, er, ec = node:range()
  return { kind = kind, row = sr, col = sc, end_row = er, end_col = ec, group = group }
end

--- Per node type: appends edits; returns true when children must not be visited.
---@type table<string, fun(node: TSNode, edits: mdp.Edit[], src: string): boolean|nil>
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

local visit

---@param sr integer
---@param sc integer
---@param er integer
---@param ec integer
---@return mdp.Edit
local function hide_range(sr, sc, er, ec)
  return { kind = "hide", row = sr, col = sc, end_row = er, end_col = ec }
end

-- `[text](dest "title")`: everything but the text is hidden.
collectors.inline_link = function(node, edits, src)
  local sr, sc, er, ec = node:range()
  for child in node:iter_children() do
    if child:type() == "link_text" then
      local tr, tc, ter, tec = child:range()
      edits[#edits + 1] = hide_range(sr, sc, tr, tc)
      edits[#edits + 1] = hide_range(ter, tec, er, ec)
      edits[#edits + 1] = edit("style", child, "MarkdownPanelLink")
      visit(child, edits, src)
      return true
    end
  end
  edits[#edits + 1] = edit("hide", node) -- `[](dest)`: no text to show
  return true
end

-- `<https://…>` / `<a@b.c>`: angle brackets hidden.
local function autolink(node, edits)
  local sr, sc, er, ec = node:range()
  edits[#edits + 1] = hide_range(sr, sc, sr, sc + 1)
  edits[#edits + 1] = hide_range(er, ec - 1, er, ec)
  edits[#edits + 1] = edit("style", node, "MarkdownPanelLink")
  return true
end
collectors.uri_autolink = autolink
collectors.email_autolink = autolink

-- `![alt](src "title")` -> `[image: alt]` (MDP-37).
collectors.image = function(node, edits, src)
  local alt = ""
  for child in node:iter_children() do
    if child:type() == "image_description" then
      alt = vim.treesitter.get_node_text(child, src):gsub("%s*\n%s*", " ")
    end
  end
  local e = edit("replace", node, "MarkdownPanelLink")
  e.text = "[image: " .. alt .. "]"
  edits[#edits + 1] = e
  return true
end

---@param node TSNode
---@param edits mdp.Edit[]
---@param src string
function visit(node, edits, src)
  local collector = collectors[node:type()]
  if collector and collector(node, edits, src) then
    return
  end
  for child in node:iter_children() do
    visit(child, edits, src)
  end
end

--- Collects the edits of every markdown_inline tree.
---@param trees TSTree[]
---@param src string  the source the trees were parsed from
---@return mdp.Edit[]
function M.collect(trees, src)
  local edits = {}
  for _, tree in ipairs(trees) do
    visit(tree:root(), edits, src)
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
  local hidden, styles, inserts = {}, {}, {}
  for _, e in ipairs(edits) do
    if e.row <= row and row <= e.end_row then
      local c1 = math.max(e.row == row and e.col or 0, col_start)
      local c2 = math.min(e.end_row == row and e.end_col or #line, #line)
      if c1 < c2 then
        if e.kind == "style" then
          styles[#styles + 1] = { c1, c2, e.group }
        else
          for c = c1, c2 - 1 do
            hidden[c] = true
          end
          -- A replaced range spanning rows shows its text on its first row only.
          if e.kind == "replace" and e.row == row then
            inserts[c1] = e
          end
        end
      end
    end
  end

  -- out_col[c]: output column of source column c (before any text inserted there).
  local highlights, seen = {}, {}
  local parts, out_col, len = {}, {}, 0
  for c = col_start, #line - 1 do
    out_col[c] = len
    local ins = inserts[c]
    if ins then
      parts[#parts + 1] = ins.text
      highlights[#highlights + 1] = { col = len, end_col = len + #ins.text, group = ins.group }
      seen[len .. ":" .. len + #ins.text .. ":" .. ins.group] = true
      len = len + #ins.text
    end
    if not hidden[c] then
      parts[#parts + 1] = line:sub(c + 1, c + 1)
      len = len + 1
    end
  end
  out_col[#line] = len

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
