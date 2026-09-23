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

-- MDP-41: syntax captures sit above CodeBlock, which keeps nvim_buf_set_extmark's
-- default priority (4096); a query's own `priority` keeps its relative order.
local EXTMARK_DEFAULT_PRIORITY = 4096

--- The `language` of the fence's info string, as source text.
---@param node TSNode fenced_code_block
---@param ctx mdp.Ctx
---@return string|nil
local function fence_language(node, ctx)
  for child in node:iter_children() do
    if child:type() == "info_string" then
      for lang in child:iter_children() do
        if lang:type() == "language" then
          local r, sc, _, ec = lang:range()
          return ctx.lines[r + 1]:sub(sc + 1, ec)
        end
      end
    end
  end
end

--- MDP-41/42: parses the emitted code text with the language's parser and puts
--- the `highlights` captures on each row's content. No parser, no query: nothing.
---@param info_lang string
---@param rows integer[] source rows of the code content, in order
---@param ctx mdp.Ctx
local function syntax(info_lang, rows, ctx)
  local lang = vim.treesitter.language.get_lang(info_lang) or info_lang
  local ok, loaded = pcall(vim.treesitter.language.add, lang)
  if not ok or not loaded then
    return
  end
  local query_ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  if not query_ok or not query then
    return
  end
  local texts = {}
  for i, r in ipairs(rows) do
    texts[i] = ctx.lines[r + 1]:sub(ctx:row(r).content_col + 1)
  end
  local src = table.concat(texts, "\n")
  local root = vim.treesitter.get_string_parser(src, lang):parse()[1]:root()
  for id, capture, metadata in query:iter_captures(root, src) do
    local name = query.captures[id]
    if name:sub(1, 1) ~= "_" and name ~= "spell" and name ~= "nospell" then
      local query_priority = metadata.priority or (metadata[id] and metadata[id].priority)
      local priority = EXTMARK_DEFAULT_PRIORITY + (tonumber(query_priority) or vim.hl.priorities.treesitter)
      local sr, sc, er, ec = capture:range()
      for i = sr, math.min(er, #rows - 1) do
        local row = ctx:row(rows[i + 1])
        row.content_hl = row.content_hl or {}
        table.insert(row.content_hl, {
          col = i == sr and sc or 0,
          end_col = i == er and ec or #texts[i + 1],
          group = "@" .. name .. "." .. lang,
          priority = priority,
        })
      end
    end
  end
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
  local content_rows = {}
  for r = first, last do
    if fence_rows[r] then
      ctx:row(r).drop = true -- the opening fence row also holds the info string
    else
      code_row(ctx, r)
      content_rows[#content_rows + 1] = r
    end
  end
  local lang = fence_language(node, ctx)
  if lang and #content_rows > 0 then
    syntax(lang, content_rows, ctx)
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
