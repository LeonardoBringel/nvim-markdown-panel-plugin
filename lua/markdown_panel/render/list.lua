-- Ordered and unordered lists (MDP-20, MDP-21) and task lists (MDP-36).
-- Each row of an item gets a list piece: the marker on its first row,
-- blanks as wide as the marker on the others. A nested item's piece
-- replaces its parent's (see Ctx:add_piece), so indentation is absolute:
-- 2 spaces per level below the first.
local M = {}

local BULLETS = { "•", "◦", "▪" }

local UNORDERED = { list_marker_minus = true, list_marker_star = true, list_marker_plus = true }
local ORDERED = { list_marker_dot = true, list_marker_parenthesis = true }
-- A task box replaces the list marker too: symbol and group.
local TASK = {
  task_list_marker_unchecked = { "☐", "MarkdownPanelUnchecked" },
  task_list_marker_checked = { "☑", "MarkdownPanelChecked" },
}

--- Number of enclosing lists, counted up to the nearest block quote.
---@param node TSNode
---@return integer
local function level_of(node)
  local level, parent = 0, node:parent()
  while parent and parent:type() ~= "block_quote" do
    if parent:type() == "list" then
      level = level + 1
    end
    parent = parent:parent()
  end
  return level
end

---@type table<string, mdp.Handler>
M.handlers = {}

function M.handlers.list(node, ctx)
  ctx:walk_children(node)
end

local function ignore() end
for marker in pairs(vim.tbl_extend("error", UNORDERED, ORDERED, TASK)) do
  M.handlers[marker] = ignore
end

function M.handlers.list_item(node, ctx)
  local level = level_of(node)
  local indent = string.rep("  ", level - 1)
  local marker, group = "", "MarkdownPanelBullet"
  for child in node:iter_children() do
    local t = child:type()
    if UNORDERED[t] or ORDERED[t] then
      local r, sc, _, ec = child:range()
      ctx:skip_to(r, ec)
      marker = UNORDERED[t] and BULLETS[math.min(level, #BULLETS)] or vim.trim(ctx.lines[r + 1]:sub(sc + 1, ec))
    elseif TASK[t] then
      local r, _, _, ec = child:range()
      ctx:skip_to(r, ec + 1) -- the box and the whitespace after it
      marker, group = TASK[t][1], TASK[t][2]
    end
  end

  local first, last = ctx:rows(node)
  ctx:add_piece(first, {
    text = indent .. marker .. " ",
    hl = { { col = #indent, end_col = #indent + #marker, group = group } },
    list = true,
  })
  local blank = { text = indent .. string.rep(" ", vim.fn.strchars(marker) + 1), hl = {}, list = true }
  for r = first + 1, last do
    ctx:add_piece(r, blank)
  end

  ctx:walk_children(node)
end

return M
