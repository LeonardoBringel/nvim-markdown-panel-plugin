local h = require("tests.unit.render.helpers")
local hl = h.hl

-- Box-drawing characters are 3 bytes each: byte columns below count them as 3.
describe("render gfm tables (MDP-34, MDP-35)", function()
  it("draws borders with columns as wide as the widest cell plus 1 space each side", function()
    local out = h.render({ "| a | bb |", "|---|---|", "| ccc | d |" })
    assert.same({
      "┌─────┬────┐",
      "│ a   │ bb │",
      "├─────┼────┤",
      "│ ccc │ d  │",
      "└─────┴────┘",
    }, out.lines)
    assert.same({
      hl(0, 0, 36, "TableBorder"),
      hl(1, 0, 3, "TableBorder"),
      hl(1, 4, 5, "TableHeader"),
      hl(1, 8, 11, "TableBorder"),
      hl(1, 12, 14, "TableHeader"),
      hl(1, 15, 18, "TableBorder"),
      hl(2, 0, 36, "TableBorder"),
      hl(3, 0, 3, "TableBorder"),
      hl(3, 8, 11, "TableBorder"),
      hl(3, 15, 18, "TableBorder"),
      hl(4, 0, 36, "TableBorder"),
    }, out.highlights)
  end)

  it("centers :-: columns (odd remainder to the right), right-aligns --: and left-aligns :--", function()
    local out = h.render({ "| ab | y | z |", "|:-:|--:|:--|", "| abcde | abc | zzz |" })
    assert.same({
      "┌───────┬─────┬─────┐",
      "│  ab   │   y │ z   │",
      "├───────┼─────┼─────┤",
      "│ abcde │ abc │ zzz │",
      "└───────┴─────┴─────┘",
    }, out.lines)
    assert.same({
      hl(0, 0, 63, "TableBorder"),
      hl(1, 0, 3, "TableBorder"),
      hl(1, 5, 7, "TableHeader"),
      hl(1, 10, 13, "TableBorder"),
      hl(1, 16, 17, "TableHeader"),
      hl(1, 18, 21, "TableBorder"),
      hl(1, 22, 23, "TableHeader"),
      hl(1, 26, 29, "TableBorder"),
      hl(2, 0, 63, "TableBorder"),
      hl(3, 0, 3, "TableBorder"),
      hl(3, 10, 13, "TableBorder"),
      hl(3, 18, 21, "TableBorder"),
      hl(3, 26, 29, "TableBorder"),
      hl(4, 0, 63, "TableBorder"),
    }, out.highlights)
  end)

  it("renders cell markup through the inline pass and measures the rendered text", function()
    local out = h.render({ "| **x** | y |", "|---|---|", "| *z* | `w` |" })
    assert.same({
      "┌───┬───┐",
      "│ x │ y │",
      "├───┼───┤",
      "│ z │ w │",
      "└───┴───┘",
    }, out.lines)
    assert.same({
      hl(0, 0, 27, "TableBorder"),
      hl(1, 0, 3, "TableBorder"),
      hl(1, 4, 5, "Bold"),
      hl(1, 4, 5, "TableHeader"),
      hl(1, 6, 9, "TableBorder"),
      hl(1, 10, 11, "TableHeader"),
      hl(1, 12, 15, "TableBorder"),
      hl(2, 0, 27, "TableBorder"),
      hl(3, 0, 3, "TableBorder"),
      hl(3, 4, 5, "Italic"),
      hl(3, 6, 9, "TableBorder"),
      hl(3, 10, 11, "Code"),
      hl(3, 12, 15, "TableBorder"),
      hl(4, 0, 27, "TableBorder"),
    }, out.highlights)
  end)

  it("pads short rows with empty cells and ignores cells beyond the header", function()
    local out = h.render({ "before", "", "| a | b |", "|---|---|", "| c |", "| d | e | f |", "", "after" })
    assert.same({
      "before",
      "",
      "┌───┬───┐",
      "│ a │ b │",
      "├───┼───┤",
      "│ c │   │",
      "│ d │ e │",
      "└───┴───┘",
      "",
      "after",
    }, out.lines)
  end)

  it("keeps an escaped pipe as cell text", function()
    local out = h.render({ "| a \\| b |", "|---|", "| c |" })
    assert.same({ "┌───────┐", "│ a | b │", "├───────┤", "│ c     │", "└───────┘" }, out.lines)
  end)

  it("prefixes every table line with the enclosing quote bar", function()
    local out = h.render({ "> | q | r |", "> |---|---|", "> | s | t |" })
    assert.same({
      "▎ ┌───┬───┐",
      "▎ │ q │ r │",
      "▎ ├───┼───┤",
      "▎ │ s │ t │",
      "▎ └───┴───┘",
    }, out.lines)
    assert.same({
      hl(0, 0, 3, "Quote"),
      hl(0, 4, 31, "TableBorder"),
      hl(1, 0, 3, "Quote"),
      hl(1, 4, 7, "TableBorder"),
      hl(1, 8, 9, "TableHeader"),
      hl(1, 10, 13, "TableBorder"),
      hl(1, 14, 15, "TableHeader"),
      hl(1, 16, 19, "TableBorder"),
      hl(2, 0, 3, "Quote"),
      hl(2, 4, 31, "TableBorder"),
      hl(3, 0, 3, "Quote"),
      hl(3, 4, 7, "TableBorder"),
      hl(3, 10, 13, "TableBorder"),
      hl(3, 16, 19, "TableBorder"),
      hl(4, 0, 3, "Quote"),
      hl(4, 4, 31, "TableBorder"),
    }, out.highlights)
  end)

  it("shows the list marker only on the first line of a table inside a list item", function()
    local out = h.render({ "- | l | m |", "  |---|---|", "  | n | o |" })
    assert.same({
      "• ┌───┬───┐",
      "  │ l │ m │",
      "  ├───┼───┤",
      "  │ n │ o │",
      "  └───┴───┘",
    }, out.lines)
  end)
end)

describe("render gfm tables with wide characters (MDP-47)", function()
  it("aligns cells by display width, not byte count", function()
    local out = h.render({ "| 日本 | a |", "|---|---|", "| x | b |" })
    assert.same({
      "┌──────┬───┐",
      "│ 日本 │ a │",
      "├──────┼───┤",
      "│ x    │ b │",
      "└──────┴───┘",
    }, out.lines)
    assert.same({
      hl(0, 0, 36, "TableBorder"),
      hl(1, 0, 3, "TableBorder"),
      hl(1, 4, 10, "TableHeader"),
      hl(1, 11, 14, "TableBorder"),
      hl(1, 15, 16, "TableHeader"),
      hl(1, 17, 20, "TableBorder"),
      hl(2, 0, 36, "TableBorder"),
      hl(3, 0, 3, "TableBorder"),
      hl(3, 9, 12, "TableBorder"),
      hl(3, 15, 18, "TableBorder"),
      hl(4, 0, 36, "TableBorder"),
    }, out.highlights)
  end)
end)
