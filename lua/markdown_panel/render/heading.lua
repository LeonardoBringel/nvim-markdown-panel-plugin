-- ATX and setext headings (MDP-13): markers and underlines removed, H<n> on the line.
local M = {}

local ATX_LEVEL = {
  atx_h1_marker = 1,
  atx_h2_marker = 2,
  atx_h3_marker = 3,
  atx_h4_marker = 4,
  atx_h5_marker = 5,
  atx_h6_marker = 6,
}

local SETEXT_LEVEL = { setext_h1_underline = 1, setext_h2_underline = 2 }

---@type table<string, mdp.Handler>
M.handlers = {}

function M.handlers.atx_heading(node, ctx)
  local r = node:range()
  local row = ctx:row(r)
  local line = ctx.lines[r + 1]
  local has_inline = false
  for child in node:iter_children() do
    local _, sc, _, ec = child:range()
    local level = ATX_LEVEL[child:type()]
    if level then
      row.group = "MarkdownPanelH" .. level
      ctx:skip_to(r, ec)
    elseif child:type() == "inline" then
      has_inline = true
      ctx:skip_to(r, sc)
      -- The parser keeps the optional closing `#` sequence inside the inline node.
      local text = line:sub(sc + 1, ec)
      local kept = text:match("^(.-)%s+#+%s*$") or (text:match("^#+%s*$") and "") or text
      row.content_end = sc + #kept
    end
  end
  if not has_inline then
    ctx:skip_to(r, #line)
  end
end

function M.handlers.setext_heading(node, ctx)
  local group
  for child in node:iter_children() do
    local level = SETEXT_LEVEL[child:type()]
    if level then
      group = "MarkdownPanelH" .. level
      local first, last = ctx:rows(child)
      for r = first, last do
        ctx:row(r).drop = true
      end
    end
  end
  for child in node:iter_children() do
    if child:type() == "paragraph" then
      local first, last = ctx:rows(child)
      for r = first, last do
        ctx:row(r).group = group
      end
      ctx:walk(child)
    end
  end
end

return M
