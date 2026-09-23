-- Fenced and indented code blocks (MDP-22, MDP-46): fences dropped, content
-- verbatim behind a 2-space lead, MarkdownPanelCodeBlock on each content line.
local M = {}

---@param ctx mdp.Ctx
---@param r integer
local function code_row(ctx, r)
  local row = ctx:row(r)
  row.lead = "  "
  row.group = "MarkdownPanelCodeBlock"
  row.verbatim = true
end

---@type table<string, mdp.Handler>
M.handlers = {}

-- An unclosed fence runs to the end of the document: the node does too.
function M.handlers.fenced_code_block(node, ctx)
  local fence_rows = {}
  for child in node:iter_children() do
    if child:type() == "fenced_code_block_delimiter" then
      fence_rows[child:range()] = true
    end
  end
  local first, last = ctx:rows(node)
  for r = first, last do
    if fence_rows[r] then
      ctx:row(r).drop = true -- the opening fence row also holds the info string
    else
      code_row(ctx, r)
    end
  end
end

function M.handlers.indented_code_block(node, ctx)
  local first, last = ctx:rows(node)
  local _, sc = node:range()
  -- Later rows strip the indentation through their block_continuation.
  ctx:skip_to(first, sc + 4)
  -- The node also spans the blank lines that follow the block.
  while last > first and ctx.lines[last + 1]:match("^%s*$") do
    last = last - 1
  end
  for r = first, last do
    code_row(ctx, r)
  end
end

return M
