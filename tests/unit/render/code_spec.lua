local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render code blocks (MDP-22)", function()
  it("drops ``` fences and prefixes content with 2 spaces, with CodeBlock", function()
    local out = h.render({ "```lua", "local x = 1", "```" })
    assert.same({ "  local x = 1" }, out.lines)
    -- The lua syntax captures on top (MDP-41) are covered by code_syntax_spec.
    local own, syntax = {}, {}
    for _, x in ipairs(out.highlights) do
      table.insert(vim.startswith(x.group, "MarkdownPanel") and own or syntax, x)
    end
    assert.same({ hl(0, 0, -1, "CodeBlock") }, own)
    for _, x in ipairs(syntax) do
      assert.matches("^@.+%.lua$", x.group)
    end
  end)

  it("treats ~~~ fences the same and keeps markdown in the content literal", function()
    local out = h.render({ "~~~", "**x** `y`", "~~~" })
    assert.same({ "  **x** `y`" }, out.lines)
    assert.same({ hl(0, 0, -1, "CodeBlock") }, out.highlights)
  end)

  it("keeps content indentation verbatim between surrounding paragraphs", function()
    local out = h.render({ "before", "```", "a", "  b", "```", "after" })
    assert.same({ "before", "  a", "    b", "after" }, out.lines)
    assert.same({ hl(1, 0, -1, "CodeBlock"), hl(2, 0, -1, "CodeBlock") }, out.highlights)
  end)

  it("renders an indented code block with the same treatment", function()
    local out = h.render({ "    local x = 1", "      nested", "", "para" })
    assert.same({ "  local x = 1", "    nested", "", "para" }, out.lines)
    assert.same({ hl(0, 0, -1, "CodeBlock"), hl(1, 0, -1, "CodeBlock") }, out.highlights)
  end)

  it("renders a fenced block inside a list item after the item indentation", function()
    local out = h.render({ "- item", "", "  ```", "  x", "  ```" })
    assert.same({ "• item", "", "    x" }, out.lines)
    assert.same({ hl(0, 0, 3, "Bullet"), hl(2, 2, -1, "CodeBlock") }, out.highlights)
  end)

  it("treats the rest of the document as code when the fence is not closed (MDP-46)", function()
    local out = h.render({ "text", "```", "a", "", "# not a heading", "- not a list" })
    assert.same({ "text", "  a", "", "  # not a heading", "  - not a list" }, out.lines)
    assert.same({
      hl(1, 0, -1, "CodeBlock"),
      hl(2, 0, -1, "CodeBlock"),
      hl(3, 0, -1, "CodeBlock"),
      hl(4, 0, -1, "CodeBlock"),
    }, out.highlights)
  end)
end)
