-- The only file of markdown-panel that Neovim loads on its own (AD-002).
-- lazy.nvim re-triggers FileType after setup(); the guard keeps a single
-- registration per buffer. b:did_ftplugin belongs to Neovim's own ftplugin.
if vim.b.markdown_panel_attached then
  return
end
vim.b.markdown_panel_attached = true

local function open()
  require("markdown_panel").open()
end

vim.api.nvim_buf_create_user_command(0, "MarkdownPanel", open, { desc = "Markdown panel" })

local keymap = require("markdown_panel.config").get().keymap
if type(keymap) == "string" then
  vim.keymap.set("n", keymap, open, { buffer = 0, desc = "Markdown panel" })
end
