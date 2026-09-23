-- Pure markdown renderer: source lines -> transformed lines + highlights (AD-001).
-- Line oriented: every source row becomes zero or one output line, unless a
-- handler replaces it with several (row.replace).

---@class mdp.Highlight
---@field row integer       0-based output row
---@field col integer       0-based byte column, inclusive
---@field end_col integer   byte column, exclusive; -1 = to end of line
---@field group string

---@class mdp.Rendered
---@field lines string[]
---@field highlights mdp.Highlight[]

---@class mdp.LineHighlight   a highlight relative to a piece of text, without row
---@field col integer
---@field end_col integer
---@field group string

---@class mdp.Piece           one container's slice of a row prefix (quote bar, list marker)
---@field text string
---@field hl mdp.LineHighlight[]
---@field list boolean|nil    list pieces are replaced by a nested list item's piece

---@class mdp.Row
---@field pieces mdp.Piece[]
---@field content_col integer         source byte column where the content starts
---@field content_end integer|nil     source byte column where the content ends (nil = end of line)
---@field lead string                 text between prefix and content, covered by `group`
---@field group string|nil            group applied from the end of the prefix to end of line
---@field drop boolean|nil            row produces no output
---@field verbatim boolean|nil        row is emitted as source text, without inline edits
---@field replace {text: string, hl: mdp.LineHighlight[]}[]|nil  output lines replacing the content

local M = {}

---@alias mdp.Handler fun(node: TSNode, ctx: mdp.Ctx)

---@type table<string, mdp.Handler>
local handlers = {}

---@class mdp.Ctx
---@field lines string[]
---@field width integer
---@field row_state table<integer, mdp.Row>
local Ctx = {}
Ctx.__index = Ctx

--- Returns the mutable state of a 0-based source row.
---@param r integer
---@return mdp.Row
function Ctx:row(r)
  local row = self.row_state[r]
  if not row then
    row = { pieces = {}, content_col = 0, lead = "" }
    self.row_state[r] = row
  end
  return row
end

--- First and last source rows a node covers. A range ending at column 0
--- does not cover its end row.
---@param node TSNode
---@return integer first, integer last
function Ctx:rows(node)
  local sr, _, er, ec = node:range()
  if ec == 0 and er > sr then
    er = er - 1
  end
  return sr, math.min(er, #self.lines - 1)
end

--- Moves the content start of row `r` to at least `col`.
---@param r integer
---@param col integer
function Ctx:skip_to(r, col)
  local row = self:row(r)
  row.content_col = math.max(row.content_col, col)
end

---@param node TSNode
function Ctx:walk(node)
  local handler = handlers[node:type()]
  if handler then
    handler(node, self)
  else
    -- MDP-26: unhandled nodes keep their source text, without inline edits.
    local first, last = self:rows(node)
    for r = first, last do
      self:row(r).verbatim = true
    end
  end
end

---@param node TSNode
function Ctx:walk_children(node)
  for child in node:iter_children() do
    if child:named() then
      self:walk(child)
    end
  end
end

local function walk_children(node, ctx)
  ctx:walk_children(node)
end

local function ignore() end

handlers.document = walk_children
handlers.section = walk_children
handlers.paragraph = walk_children
handlers.inline = ignore
handlers.block_continuation = ignore

--- Continuation markers (`> `, list indentation) precede the content of their row,
--- wherever they appear in the tree.
---@param node TSNode
---@param ctx mdp.Ctx
local function skip_continuations(node, ctx)
  if node:type() == "block_continuation" then
    local sr, _, _, ec = node:range()
    ctx:skip_to(sr, ec)
    return
  end
  for child in node:iter_children() do
    skip_continuations(child, ctx)
  end
end

---@param lang string
---@return string|nil err
local function load_parser(lang)
  local ok, loaded = pcall(vim.treesitter.language.add, lang)
  if not ok or not loaded then
    return ('markdown-panel: treesitter parser "%s" not found'):format(lang)
  end
end

--- Concatenates a row's prefix pieces into text + absolute highlights.
---@param row mdp.Row
---@return string, mdp.LineHighlight[]
local function build_prefix(row)
  local text, hl = "", {}
  for _, piece in ipairs(row.pieces) do
    for _, p in ipairs(piece.hl) do
      hl[#hl + 1] = { col = #text + p.col, end_col = #text + p.end_col, group = p.group }
    end
    text = text .. piece.text
  end
  return text, hl
end

---@param out mdp.Rendered
---@param text string
---@param hl mdp.LineHighlight[]
local function emit(out, text, hl)
  local row = #out.lines
  out.lines[row + 1] = text
  for _, h in ipairs(hl) do
    if h.end_col == -1 or h.end_col > h.col then
      out.highlights[#out.highlights + 1] = { row = row, col = h.col, end_col = h.end_col, group = h.group }
    end
  end
end

---@param hl mdp.LineHighlight[]
---@param from mdp.LineHighlight[]
---@param shift integer
local function append_shifted(hl, from, shift)
  for _, h in ipairs(from) do
    hl[#hl + 1] = { col = h.col + shift, end_col = h.end_col == -1 and -1 or h.end_col + shift, group = h.group }
  end
end

---@param ctx mdp.Ctx
---@param r integer
---@param out mdp.Rendered
local function assemble_row(ctx, r, out)
  local row = ctx:row(r)
  if row.drop then
    return
  end
  local prefix, hl = build_prefix(row)
  if row.replace then
    for _, item in ipairs(row.replace) do
      local line_hl = vim.deepcopy(hl)
      append_shifted(line_hl, item.hl, #prefix)
      emit(out, prefix .. item.text, line_hl)
    end
    return
  end
  local line = ctx.lines[r + 1]
  if row.content_end then
    line = line:sub(1, row.content_end)
  end
  local content = line:sub(row.content_col + 1)
  local head = prefix .. row.lead
  if content == "" then
    -- Blank content: keep the line blank apart from visible markers (MDP-27).
    head = head:gsub("%s+$", "")
  end
  if row.group then
    hl[#hl + 1] = { col = #prefix, end_col = -1, group = row.group }
  end
  for _, h in ipairs(hl) do
    h.end_col = h.end_col == -1 and -1 or math.min(h.end_col, #head)
  end
  emit(out, head .. content, hl)
end

--- Renders markdown source lines.
---@param lines string[]
---@param opts {width: integer}
---@return mdp.Rendered|nil rendered
---@return string|nil err
function M.render(lines, opts)
  for _, lang in ipairs({ "markdown", "markdown_inline" }) do
    local err = load_parser(lang)
    if err then
      return nil, err
    end
  end

  -- The trailing newline makes the last line a complete block (a final `---`
  -- is otherwise parsed as paragraph text).
  local src = table.concat(lines, "\n") .. "\n"
  local parser = vim.treesitter.get_string_parser(src, "markdown")
  local root = parser:parse(true)[1]:root()

  local ctx = setmetatable({ lines = lines, width = opts.width, row_state = {} }, Ctx)
  skip_continuations(root, ctx)
  ctx:walk(root)

  ---@type mdp.Rendered
  local out = { lines = {}, highlights = {} }
  for r = 0, #lines - 1 do
    assemble_row(ctx, r, out)
  end
  return out
end

return M
