local M = {}

---@type table<string, vim.api.keyset.highlight>
M.groups = {
  MarkdownPanelH1 = { link = "@markup.heading.1.markdown", default = true },
  MarkdownPanelH2 = { link = "@markup.heading.2.markdown", default = true },
  MarkdownPanelH3 = { link = "@markup.heading.3.markdown", default = true },
  MarkdownPanelH4 = { link = "@markup.heading.4.markdown", default = true },
  MarkdownPanelH5 = { link = "@markup.heading.5.markdown", default = true },
  MarkdownPanelH6 = { link = "@markup.heading.6.markdown", default = true },
  MarkdownPanelBold = { link = "@markup.strong", default = true },
  MarkdownPanelItalic = { link = "@markup.italic", default = true },
  MarkdownPanelStrike = { link = "@markup.strikethrough", default = true },
  MarkdownPanelCode = { link = "@markup.raw", default = true },
  MarkdownPanelCodeBlock = { link = "@markup.raw.block", default = true },
  MarkdownPanelLink = { link = "@markup.link.label", default = true },
  MarkdownPanelBullet = { link = "@markup.list", default = true },
  MarkdownPanelQuote = { link = "@markup.quote", default = true },
  MarkdownPanelRule = { link = "@punctuation.special", default = true },
  MarkdownPanelTableHeader = { link = "@markup.heading", default = true },
  MarkdownPanelTableBorder = { link = "@punctuation.special", default = true },
  MarkdownPanelChecked = { link = "@markup.list.checked", default = true },
  MarkdownPanelUnchecked = { link = "@markup.list.unchecked", default = true },
  MarkdownPanelNormal = { link = "Normal", default = true },
  MarkdownPanelBorder = { link = "Normal", default = true },
  MarkdownPanelFooter = { link = "Normal", default = true },
}

function M.setup()
  for name, def in pairs(M.groups) do
    vim.api.nvim_set_hl(0, name, def)
  end
end

return M
