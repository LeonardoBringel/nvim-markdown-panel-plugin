local h = require("tests.unit.render.helpers")
local hl = h.hl

local BAR = #"▎" -- 3 bytes; "▎ " is 4

describe("render block quotes (MDP-23)", function()
  it("replaces > by ▎ with Quote on the bar", function()
    local out = h.render({ "> a" })
    assert.same({ "▎ a" }, out.lines)
    assert.same({ hl(0, 0, BAR, "Quote") }, out.highlights)
  end)

  it("renders one bar per nesting level", function()
    local out = h.render({ "> > a" })
    assert.same({ "▎ ▎ a" }, out.lines)
    assert.same({ hl(0, 0, BAR, "Quote"), hl(0, 4, 4 + BAR, "Quote") }, out.highlights)
  end)

  it("does not leak > into bold spanning two quoted lines", function()
    local out = h.render({ "> a **b", "> c** d" })
    assert.same({ "▎ a b", "▎ c d" }, out.lines)
    assert.same({
      hl(0, 0, BAR, "Quote"),
      hl(0, 6, 7, "Bold"),
      hl(1, 0, BAR, "Quote"),
      hl(1, 4, 5, "Bold"),
    }, out.highlights)
  end)

  it("keeps the bar on blank and lazy continuation lines of the quote", function()
    local out = h.render({ "> a", ">", "> b", "lazy" })
    assert.same({ "▎ a", "▎", "▎ b", "▎ lazy" }, out.lines)
    assert.same({
      hl(0, 0, BAR, "Quote"),
      hl(1, 0, BAR, "Quote"),
      hl(2, 0, BAR, "Quote"),
      hl(3, 0, BAR, "Quote"),
    }, out.highlights)
  end)

  it("renders a list inside a quote after the bar (MDP-23, MDP-20)", function()
    local out = h.render({ "> - a" })
    assert.same({ "▎ • a" }, out.lines)
    assert.same({ hl(0, 0, BAR, "Quote"), hl(0, 4, 7, "Bullet") }, out.highlights)
  end)

  it("ends the quote at the blank line that follows it", function()
    local out = h.render({ "> q", "", "after" })
    assert.same({ "▎ q", "", "after" }, out.lines)
    assert.same({ hl(0, 0, BAR, "Quote") }, out.highlights)
  end)
end)

describe("render thematic breaks (MDP-24)", function()
  for _, source in ipairs({ "---", "***", "___" }) do
    it(("renders %s as ─ repeated width times, with Rule"):format(source), function()
      local out = h.render({ source }, 10)
      assert.same({ string.rep("─", 10) }, out.lines)
      assert.same({ hl(0, 0, -1, "Rule") }, out.highlights)
    end)
  end

  it("keeps surrounding blank lines and paragraphs in place", function()
    local out = h.render({ "a", "", "***", "", "b" }, 5)
    assert.same({ "a", "", string.rep("─", 5), "", "b" }, out.lines)
    assert.same({ hl(2, 0, -1, "Rule") }, out.highlights)
  end)
end)
