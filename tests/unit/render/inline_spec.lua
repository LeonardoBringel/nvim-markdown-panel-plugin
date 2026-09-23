local h = require("tests.unit.render.helpers")
local hl = h.hl

describe("render inline", function()
  it("renders **bold** without delimiters and with Bold (MDP-14)", function()
    local out = h.render({ "a **b** c" })
    assert.same({ "a b c" }, out.lines)
    assert.same({ hl(0, 2, 3, "Bold") }, out.highlights)
  end)

  it("renders __bold__ without delimiters and with Bold (MDP-14)", function()
    local out = h.render({ "a __b__ c" })
    assert.same({ "a b c" }, out.lines)
    assert.same({ hl(0, 2, 3, "Bold") }, out.highlights)
  end)

  it("renders *italic* without delimiters and with Italic (MDP-15)", function()
    local out = h.render({ "*i*" })
    assert.same({ "i" }, out.lines)
    assert.same({ hl(0, 0, 1, "Italic") }, out.highlights)
  end)

  it("renders _italic_ without delimiters and with Italic (MDP-15)", function()
    local out = h.render({ "x _i_ y" })
    assert.same({ "x i y" }, out.lines)
    assert.same({ hl(0, 2, 3, "Italic") }, out.highlights)
  end)

  it("renders ***bold italic*** with both Bold and Italic (MDP-14, MDP-15)", function()
    local out = h.render({ "***bi***" })
    assert.same({ "bi" }, out.lines)
    assert.same({ hl(0, 0, 2, "Bold"), hl(0, 0, 2, "Italic") }, out.highlights)
  end)

  it("renders ~~strike~~ with a single Strike and no tilde left (MDP-16)", function()
    local out = h.render({ "~~s~~" })
    assert.same({ "s" }, out.lines)
    assert.same({ hl(0, 0, 1, "Strike") }, out.highlights)
  end)

  it("renders a code span without backticks and without parsing inside it (MDP-17)", function()
    local out = h.render({ "`**x**`" })
    assert.same({ "**x**" }, out.lines)
    assert.same({ hl(0, 0, 5, "Code") }, out.highlights)
  end)

  it("renders escaped characters literally and unformatted (MDP-25)", function()
    local out = h.render({ "\\*x\\*" })
    assert.same({ "*x*" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("clips bold spanning two paragraph lines to each line (MDP-14)", function()
    local out = h.render({ "a **b", "c** d" })
    assert.same({ "a b", "c d" }, out.lines)
    assert.same({ hl(0, 2, 3, "Bold"), hl(1, 0, 1, "Bold") }, out.highlights)
  end)

  it("renders inline formatting inside a heading (MDP-13, MDP-14)", function()
    local out = h.render({ "# A **b**" })
    assert.same({ "A b" }, out.lines)
    assert.same({ hl(0, 0, -1, "H1"), hl(0, 2, 3, "Bold") }, out.highlights)
  end)

  it("uses output byte columns with multibyte text (MDP-14)", function()
    local out = h.render({ "é **ção** ü" })
    assert.same({ "é ção ü" }, out.lines)
    -- "é " is 3 bytes, "ção" is 5 bytes.
    assert.same({ hl(0, 3, 8, "Bold") }, out.highlights)
  end)

  it("combines several inline elements on one line (MDP-14..17, MDP-25)", function()
    local out = h.render({ "`c` **b** *i* ~~s~~ \\_" })
    assert.same({ "c b i s _" }, out.lines)
    assert.same({
      hl(0, 0, 1, "Code"),
      hl(0, 2, 3, "Bold"),
      hl(0, 4, 5, "Italic"),
      hl(0, 6, 7, "Strike"),
    }, out.highlights)
  end)
end)
