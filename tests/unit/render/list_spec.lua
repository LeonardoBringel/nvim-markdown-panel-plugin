local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render lists", function()
  for _, marker in ipairs({ "-", "*", "+" }) do
    it(("replaces the %q marker by • with Bullet on its bytes (MDP-20)"):format(marker), function()
      local out = h.render({ marker .. " a" })
      assert.same({ "• a" }, out.lines)
      assert.same({ hl(0, 0, #"•", "Bullet") }, out.highlights)
    end)
  end

  it("uses • ◦ ▪ per level, 2 spaces per level, ▪ from level 3 on (MDP-20)", function()
    local out = h.render({ "- a", "  - b", "    - c", "      - d" })
    assert.same({ "• a", "  ◦ b", "    ▪ c", "      ▪ d" }, out.lines)
    assert.same({
      hl(0, 0, 3, "Bullet"),
      hl(1, 2, 5, "Bullet"),
      hl(2, 4, 7, "Bullet"),
      hl(3, 6, 9, "Bullet"),
    }, out.highlights)
  end)

  it("keeps ordered markers as written, with Bullet on the marker (MDP-21)", function()
    local out = h.render({ "1. um", "", "2) dois" })
    assert.same({ "1. um", "", "2) dois" }, out.lines)
    assert.same({ hl(0, 0, 2, "Bullet"), hl(2, 0, 2, "Bullet") }, out.highlights)
  end)

  it("keeps multi-digit ordered markers (MDP-21)", function()
    local out = h.render({ "10) ten" })
    assert.same({ "10) ten" }, out.lines)
    assert.same({ hl(0, 0, 3, "Bullet") }, out.highlights)
  end)

  it("indents a list nested in an ordered item by 2 spaces per level (MDP-20, MDP-21)", function()
    local out = h.render({ "1. a", "   - b" })
    assert.same({ "1. a", "  ◦ b" }, out.lines)
    assert.same({ hl(0, 0, 2, "Bullet"), hl(1, 2, 5, "Bullet") }, out.highlights)
  end)

  it("keeps Bold inside an item, shifted by the prefix (MDP-20, MDP-14)", function()
    local out = h.render({ "- **x** y" })
    assert.same({ "• x y" }, out.lines)
    -- "• " is 4 bytes.
    assert.same({ hl(0, 0, 3, "Bullet"), hl(0, 4, 5, "Bold") }, out.highlights)
  end)

  it("aligns item continuation lines with the item text (MDP-20)", function()
    local out = h.render({ "- first", "  continued", "  - nested", "    more" })
    assert.same({ "• first", "  continued", "  ◦ nested", "    more" }, out.lines)
    assert.same({ hl(0, 0, 3, "Bullet"), hl(2, 2, 5, "Bullet") }, out.highlights)
  end)

  it("keeps blank lines between items blank (MDP-20, MDP-27)", function()
    local out = h.render({ "- a", "", "- b" })
    assert.same({ "• a", "", "• b" }, out.lines)
    assert.same({ hl(0, 0, 3, "Bullet"), hl(2, 0, 3, "Bullet") }, out.highlights)
  end)
end)
