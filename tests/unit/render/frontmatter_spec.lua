local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render frontmatter", function()
  it("omits a leading YAML block delimited by --- (MDP-38)", function()
    local out = h.render({ "---", "title: x", "---", "# T" })
    assert.same({ "T" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1") }, out.highlights)
  end)

  it("omits a multi-key frontmatter and keeps the blank line after it (MDP-38, MDP-27)", function()
    local out = h.render({ "---", "title: x", "tags: [a, b]", "---", "", "text" })
    assert.same({ "", "text" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("renders a document made only of frontmatter as nothing (MDP-38)", function()
    local out = h.render({ "---", "a: 1", "---" })
    assert.same({}, out.lines)
    assert.same({}, out.highlights)
  end)

  it("keeps a --- that is not on line 1 as a thematic break (MDP-38, MDP-24)", function()
    local out = h.render({ "a", "", "---", "", "b" }, 4)
    assert.same({ "a", "", "────", "", "b" }, out.lines)
    assert.same({ hl(2, 0, -1, "Rule") }, out.highlights)
  end)

  it("keeps a --- block after the first line as content (MDP-38, MDP-24, MDP-13)", function()
    local out = h.render({ "a", "", "---", "title: x", "---" }, 4)
    assert.same({ "a", "", "────", "title: x" }, out.lines)
    assert.same({ hl(2, 0, -1, "Rule"), hl(3, 0, -1, "H2") }, out.highlights)
  end)
end)
