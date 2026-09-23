local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render images", function()
  it("replaces ![alt](src) by [image: alt] with Link on all of it (MDP-37)", function()
    local out = h.render({ "![logo](a.png)" })
    assert.same({ "[image: logo]" }, out.lines)
    assert.same({ hl(0, 0, #"[image: logo]", "Link") }, out.highlights)
  end)

  it("keeps the text around an image with an empty alt (MDP-37)", function()
    local out = h.render({ "x ![](a.png) y" })
    assert.same({ "x [image: ] y" }, out.lines)
    assert.same({ hl(0, 2, 11, "Link") }, out.highlights)
  end)

  it("drops the image title (MDP-37)", function()
    local out = h.render({ '![logo](a.png "The logo")' })
    assert.same({ "[image: logo]" }, out.lines)
    assert.same({ hl(0, 0, 13, "Link") }, out.highlights)
  end)

  it("shifts the styles after an image by the placeholder width (MDP-37, MDP-14, MDP-15)", function()
    local out = h.render({ "**b** ![a](i.png) *c*" })
    assert.same({ "b [image: a] c" }, out.lines)
    assert.same({ hl(0, 0, 1, "Bold"), hl(0, 2, 12, "Link"), hl(0, 13, 14, "Italic") }, out.highlights)
  end)

  it("keeps a style wrapping an image over the placeholder (MDP-37, MDP-14)", function()
    local out = h.render({ "**![a](i.png)**" })
    assert.same({ "[image: a]" }, out.lines)
    assert.same({ hl(0, 0, 10, "Bold"), hl(0, 0, 10, "Link") }, out.highlights)
  end)

  it("keeps a multibyte alt with Link over all its bytes (MDP-37)", function()
    local out = h.render({ "![café](c.png)" })
    assert.same({ "[image: café]" }, out.lines)
    -- "café" is 5 bytes.
    assert.same({ hl(0, 0, 14, "Link") }, out.highlights)
  end)

  it("renders a linked image as one placeholder with a single Link (MDP-37, MDP-18)", function()
    local out = h.render({ "[![a](i.png)](https://x.y)" })
    assert.same({ "[image: a]" }, out.lines)
    assert.same({ hl(0, 0, 10, "Link") }, out.highlights)
  end)

  it("puts the placeholder of a multi-line image on its first row, alt joined by a space (MDP-37)", function()
    local out = h.render({ "![a", "b](x.png) z" })
    assert.same({ "[image: a b]", " z" }, out.lines)
    assert.same({ hl(0, 0, 12, "Link") }, out.highlights)
  end)

  it("places the placeholder after a list prefix (MDP-37, MDP-20)", function()
    local out = h.render({ "- ![a](i.png)" })
    assert.same({ "• [image: a]" }, out.lines)
    assert.same({ hl(0, 0, 3, "Bullet"), hl(0, 4, 14, "Link") }, out.highlights)
  end)
end)
