local h = require("tests.unit.render.helpers")
local render = require("markdown_panel.render")

describe("render core", function()
  it("emits a plain paragraph unchanged and without highlights", function()
    local out = h.render({ "Hello world, plain text.", "Second line of the same paragraph." })
    assert.same({ "Hello world, plain text.", "Second line of the same paragraph." }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("emits an HTML block verbatim without highlights (MDP-26)", function()
    local out = h.render({ "<div>hi</div>" })
    assert.same({ "<div>hi</div>" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("keeps markdown inside an HTML block verbatim (MDP-26)", function()
    local out = h.render({ "<div>", "**not bold** `nor code`", "</div>" })
    assert.same({ "<div>", "**not bold** `nor code`", "</div>" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("emits inline HTML verbatim without highlights (MDP-26)", function()
    local out = h.render({ "a <span class=\"x\">b</span> c" })
    assert.same({ "a <span class=\"x\">b</span> c" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("emits an unhandled node (link reference definition) verbatim (MDP-26)", function()
    local out = h.render({ "[ref]: https://example.com" })
    assert.same({ "[ref]: https://example.com" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("preserves blank lines between blocks (MDP-27)", function()
    local out = h.render({ "a", "", "", "b" })
    assert.same({ "a", "", "", "b" }, out.lines)
    assert.same({}, out.highlights)
  end)

  it("is pure: same input gives equal output and creates no buffer (MDP-28)", function()
    local input = { "# Title", "", "some **bold** text", "", "- item", "", "```lua", "x = 1", "```" }
    local bufs_before = #vim.api.nvim_list_bufs()
    local first = render.render(input, { width = 40 })
    local second = render.render(input, { width = 40 })
    assert.is_true(vim.deep_equal(first, second))
    assert.are.equal(bufs_before, #vim.api.nvim_list_bufs())
    assert.same({ "# Title", "", "some **bold** text", "", "- item", "", "```lua", "x = 1", "```" }, input)
  end)

  describe("when a parser cannot be loaded", function()
    local original_add

    before_each(function()
      original_add = vim.treesitter.language.add
    end)

    after_each(function()
      vim.treesitter.language.add = original_add
    end)

    local function fail_for(target, mode)
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.treesitter.language.add = function(lang, ...)
        if lang == target then
          if mode == "throw" then
            error("no parser for " .. lang)
          end
          return nil, "no parser for " .. lang
        end
        return original_add(lang, ...)
      end
    end

    it("returns nil and the error message for a missing markdown parser", function()
      fail_for("markdown")
      local rendered, err = render.render({ "# a" }, { width = 80 })
      assert.is_nil(rendered)
      assert.are.equal('markdown-panel: treesitter parser "markdown" not found', err)
    end)

    it("returns nil and the error message for a missing markdown_inline parser", function()
      fail_for("markdown_inline")
      local rendered, err = render.render({ "# a" }, { width = 80 })
      assert.is_nil(rendered)
      assert.are.equal('markdown-panel: treesitter parser "markdown_inline" not found', err)
    end)

    it("reports the missing parser when language.add raises instead of returning nil", function()
      fail_for("markdown", "throw")
      local rendered, err = render.render({ "# a" }, { width = 80 })
      assert.is_nil(rendered)
      assert.are.equal('markdown-panel: treesitter parser "markdown" not found', err)
    end)
  end)
end)
