local h = require("tests.unit.render.helpers")
local hl = h.hl

-- nvim_buf_set_extmark's priority when none is given: what CodeBlock gets.
local DEFAULT_EXTMARK_PRIORITY = 4096

---@param highlights mdp.Highlight[]
---@param row integer
---@param col integer
---@param end_col integer
---@return mdp.Highlight[]
local function at(highlights, row, col, end_col)
  return vim.tbl_filter(function(x)
    return x.row == row and x.col == col and x.end_col == end_col
  end, highlights)
end

---@param highlights mdp.Highlight[]
---@return mdp.Highlight
local function code_block(highlights, row)
  local found = vim.tbl_filter(function(x)
    return x.row == row and x.group == "MarkdownPanelCodeBlock"
  end, highlights)
  assert.are.equal(1, #found)
  return found[1]
end

---@param highlights mdp.Highlight[]
---@param row integer
---@param col integer
---@param end_col integer
---@param group string
local function assert_capture(highlights, row, col, end_col, group)
  local found = at(highlights, row, col, end_col)
  assert.are.same({ group }, vim.tbl_map(function(x)
    return x.group
  end, found))
  local base = code_block(highlights, row).priority or DEFAULT_EXTMARK_PRIORITY
  assert.is_number(found[1].priority)
  assert.is_true(found[1].priority > base)
end

describe("render code block syntax (MDP-41, MDP-42)", function()
  local notify, notify_calls

  before_each(function()
    notify = vim.notify
    notify_calls = 0
    vim.notify = function()
      notify_calls = notify_calls + 1
    end
  end)

  after_each(function()
    vim.notify = notify
  end)

  it("highlights `local` in a lua block with the lua capture above CodeBlock (MDP-41)", function()
    local out = h.render({ "```lua", "local x = 1", "```" })
    assert.same({ "  local x = 1" }, out.lines)
    assert_capture(out.highlights, 0, 2, 7, "@keyword.lua")
    assert.is_nil(code_block(out.highlights, 0).priority)
  end)

  it("maps captures to the right output row and after the list prefix (MDP-41)", function()
    local out = h.render({ "- item", "", "  ```lua", "  x = 1", "  local y", "  ```" })
    assert.same({ "• item", "", "    x = 1", "    local y" }, out.lines)
    assert_capture(out.highlights, 3, 4, 9, "@keyword.lua")
  end)

  it("splits a capture spanning rows into one highlight per output row (MDP-41)", function()
    local out = h.render({ "```lua", "--[[ a", "b ]]", "```" })
    assert.same({ "  --[[ a", "  b ]]" }, out.lines)
    assert_capture(out.highlights, 0, 2, 8, "@comment.lua")
    assert_capture(out.highlights, 1, 2, 6, "@comment.lua")
  end)

  it("applies only CodeBlock for a language without a parser, silently (MDP-42)", function()
    local out = h.render({ "```naoexiste", "local x = 1", "```" })
    assert.same({ "  local x = 1" }, out.lines)
    assert.same({ hl(0, 0, -1, "CodeBlock") }, out.highlights)
    assert.are.equal(0, notify_calls)
  end)

  it("applies only CodeBlock for an invalid language name, silently (MDP-42)", function()
    local out = h.render({ "```c++", "int x;", "```" })
    assert.same({ hl(0, 0, -1, "CodeBlock") }, out.highlights)
    assert.are.equal(0, notify_calls)
  end)

  it("applies only CodeBlock to a fence without a language (MDP-42)", function()
    local out = h.render({ "```", "local x = 1", "```" })
    assert.same({ "  local x = 1" }, out.lines)
    assert.same({ hl(0, 0, -1, "CodeBlock") }, out.highlights)
    assert.are.equal(0, notify_calls)
  end)
end)
