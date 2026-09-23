local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render headings (MDP-13)", function()
  local atx = { "A", "B", "C", "D", "E", "F" }
  for level, text in ipairs(atx) do
    it(("renders ATX level %d without markers, H%d on the whole line"):format(level, level), function()
      local out = h.render({ string.rep("#", level) .. " " .. text })
      assert.same({ text }, out.lines)
      assert.same({ hl(0, 0, -1, "H" .. level) }, out.highlights)
    end)
  end

  it("renders a setext === heading as H1 and drops the underline", function()
    local out = h.render({ "Title", "===" })
    assert.same({ "Title" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1") }, out.highlights)
  end)

  it("renders a setext --- heading as H2 and drops the underline", function()
    local out = h.render({ "Sub", "---" })
    assert.same({ "Sub" }, out.lines)
    assert.same({ hl(0, 0, -1, "H2") }, out.highlights)
  end)

  it("applies the setext level to every line of a multi-line setext heading", function()
    local out = h.render({ "first", "second", "=====" })
    assert.same({ "first", "second" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1"), hl(1, 0, -1, "H1") }, out.highlights)
  end)

  it("renders a bare # as an empty line with H1", function()
    local out = h.render({ "#" })
    assert.same({ "" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1") }, out.highlights)
  end)

  it("keeps #foo (no space) as a verbatim paragraph", function()
    local out = h.render({ "#foo" })
    assert.same({ "#foo" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("drops the optional ATX closing sequence", function()
    local out = h.render({ "## Closed ##" })
    assert.same({ "Closed" }, out.lines)
    assert.same({ hl(0, 0, -1, "H2") }, out.highlights)
  end)

  it("highlights only the heading row among other blocks", function()
    local out = h.render({ "# Top", "", "body text", "### Third" })
    assert.same({ "Top", "", "body text", "Third" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1"), hl(3, 0, -1, "H3") }, out.highlights)
  end)
end)
