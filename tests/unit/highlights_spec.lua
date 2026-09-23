local function fresh_highlights()
  package.loaded["markdown_panel.highlights"] = nil
  return require("markdown_panel.highlights")
end

local expected_links = {
  MarkdownPanelH1 = "@markup.heading.1.markdown",
  MarkdownPanelH2 = "@markup.heading.2.markdown",
  MarkdownPanelH3 = "@markup.heading.3.markdown",
  MarkdownPanelH4 = "@markup.heading.4.markdown",
  MarkdownPanelH5 = "@markup.heading.5.markdown",
  MarkdownPanelH6 = "@markup.heading.6.markdown",
  MarkdownPanelBold = "@markup.strong",
  MarkdownPanelItalic = "@markup.italic",
  MarkdownPanelStrike = "@markup.strikethrough",
  MarkdownPanelCode = "@markup.raw",
  MarkdownPanelCodeBlock = "@markup.raw.block",
  MarkdownPanelLink = "@markup.link.label",
  MarkdownPanelBullet = "@markup.list",
  MarkdownPanelQuote = "@markup.quote",
  MarkdownPanelRule = "@punctuation.special",
  MarkdownPanelTableHeader = "@markup.heading",
  MarkdownPanelTableBorder = "@punctuation.special",
  MarkdownPanelChecked = "@markup.list.checked",
  MarkdownPanelUnchecked = "@markup.list.unchecked",
}

describe("markdown_panel.highlights", function()
  before_each(function()
    for name, _ in pairs(expected_links) do
      pcall(vim.api.nvim_set_hl, 0, name, {})
    end
  end)

  it("defines every design-listed MarkdownPanel* group with default = true after setup()", function()
    local highlights = fresh_highlights()
    highlights.setup()

    for name, link in pairs(expected_links) do
      local hl = vim.api.nvim_get_hl(0, { name = name, link = true })
      assert.are.equal(link, hl.link, "group " .. name .. " should link to " .. link)
      assert.are.equal(true, hl.default, "group " .. name .. " should be default = true")
    end
  end)

  it("does not overwrite a group the user defined before setup()", function()
    vim.api.nvim_set_hl(0, "MarkdownPanelH1", { fg = "#ff0000" })

    local highlights = fresh_highlights()
    highlights.setup()

    local hl = vim.api.nvim_get_hl(0, { name = "MarkdownPanelH1" })
    assert.are.equal("#ff0000", string.format("#%06x", hl.fg))
  end)

  it("calling setup() twice does not fail nor change the result", function()
    local highlights = fresh_highlights()
    highlights.setup()
    local first = vim.api.nvim_get_hl(0, { name = "MarkdownPanelH1", link = true })

    assert.has_no.error(function()
      highlights.setup()
    end)

    local second = vim.api.nvim_get_hl(0, { name = "MarkdownPanelH1", link = true })
    assert.are.same(first, second)
  end)
end)
