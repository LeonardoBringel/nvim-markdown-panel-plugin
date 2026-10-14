-- h.render drops fields other than lines/highlights, so these specs call render() directly.
local render = require("markdown_panel.render")

---@param lines string[]
---@return integer[]
local function line_map(lines)
  local rendered, err = render.render(lines, { width = 40 })
  assert(rendered, err)
  return rendered.line_map
end

describe("render line_map", function()
  it("has one entry per source line, each at its preview line (CUR-01)", function()
    local map = line_map({ "a", "b", "", "c" })
    assert.are.equal(4, #map)
    assert.same({ 1, 2, 3, 4 }, map)
  end)

  it("maps hidden frontmatter to the first content line (CUR-02, CUR-04)", function()
    assert.same({ 1, 1, 1, 1, 2, 3 }, line_map({ "---", "a: 1", "---", "# T", "", "x" }))
  end)

  it("maps each table row to the first preview line it produced (CUR-01, CUR-05)", function()
    assert.same({ 1, 2, 4, 6, 7 }, line_map({ "| a |", "|---|", "| b |", "", "x" }))
  end)

  it("maps a setext underline to the next rendered line (CUR-02, CUR-06)", function()
    assert.same({ 1, 2, 2, 3 }, line_map({ "T", "===", "", "x" }))
  end)

  it("maps fences to the code line or, at end of file, to the last preview line (CUR-03, CUR-07)", function()
    assert.same({ 1, 1, 1 }, line_map({ "```lua", "print(1)", "```" }))
  end)

  it("maps every line to 1 when the render produces no lines (CUR-03)", function()
    local rendered, err = render.render({ "---", "a: 1", "---" }, { width = 40 })
    assert(rendered, err)
    assert.same({}, rendered.lines)
    assert.same({ 1, 1, 1 }, rendered.line_map)
  end)
end)
