local h = require("tests.unit.render.helpers")
local hl = h.hl

-- "☐" and "☑" are 3 bytes each.
describe("render task lists", function()
  it("replaces an unchecked marker and box by ☐ with Unchecked (MDP-36)", function()
    local out = h.render({ "- [ ] a" })
    assert.same({ "☐ a" }, out.lines)
    assert.same({ hl(0, 0, 3, "Unchecked") }, out.highlights)
  end)

  for _, box in ipairs({ "[x]", "[X]" }) do
    it(("replaces a %s checked marker and box by ☑ with Checked (MDP-36)"):format(box), function()
      local out = h.render({ "- " .. box .. " a" })
      assert.same({ "☑ a" }, out.lines)
      assert.same({ hl(0, 0, 3, "Checked") }, out.highlights)
    end)
  end

  it("indents nested tasks by 2 spaces per level (MDP-36, MDP-20)", function()
    local out = h.render({ "- [ ] a", "  - [x] b", "    - [ ] c" })
    assert.same({ "☐ a", "  ☑ b", "    ☐ c" }, out.lines)
    assert.same({
      hl(0, 0, 3, "Unchecked"),
      hl(1, 2, 5, "Checked"),
      hl(2, 4, 7, "Unchecked"),
    }, out.highlights)
  end)

  it("replaces an ordered marker and box too (MDP-36, MDP-21)", function()
    local out = h.render({ "1. [x] a", "2) [ ] b" })
    assert.same({ "☑ a", "☐ b" }, out.lines)
    assert.same({ hl(0, 0, 3, "Checked"), hl(1, 0, 3, "Unchecked") }, out.highlights)
  end)

  it("keeps plain items of the same list as bullets (MDP-36, MDP-20)", function()
    local out = h.render({ "- [ ] a", "- b" })
    assert.same({ "☐ a", "• b" }, out.lines)
    assert.same({ hl(0, 0, 3, "Unchecked"), hl(1, 0, 3, "Bullet") }, out.highlights)
  end)

  it("aligns a task's continuation line with its text (MDP-36)", function()
    local out = h.render({ "- [x] a", "  b" })
    assert.same({ "☑ a", "  b" }, out.lines)
    assert.same({ hl(0, 0, 3, "Checked") }, out.highlights)
  end)

  it("keeps inline styles after the box, shifted by the prefix (MDP-36, MDP-14)", function()
    local out = h.render({ "- [x] **a** b" })
    assert.same({ "☑ a b" }, out.lines)
    assert.same({ hl(0, 0, 3, "Checked"), hl(0, 4, 5, "Bold") }, out.highlights)
  end)
end)
