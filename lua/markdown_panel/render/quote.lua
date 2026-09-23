-- Block quotes (MDP-23): every row of a quote gets a `▎ ` piece per nesting
-- level, with MarkdownPanelQuote on the bar.
local M = {}

local BAR = "▎"

---@type mdp.Piece
local PIECE = { text = BAR .. " ", hl = { { col = 0, end_col = #BAR, group = "MarkdownPanelQuote" } } }

---@type table<string, mdp.Handler>
M.handlers = {}

function M.handlers.block_quote(node, ctx)
  local first, last = ctx:rows(node)
  for r = first, last do
    ctx:add_piece(r, PIECE)
  end
  for child in node:iter_children() do
    if child:type() == "block_quote_marker" then
      local r, _, _, ec = child:range()
      ctx:skip_to(r, ec)
    end
  end
  ctx:walk_children(node)
end

function M.handlers.block_quote_marker() end

return M
