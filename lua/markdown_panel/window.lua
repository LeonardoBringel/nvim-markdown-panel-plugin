local M = {}

local ns = vim.api.nvim_create_namespace("markdown_panel")

---@type integer|nil
local preview_win

---80% of the editor area, centered. The border adds one cell on each side,
---so the outer box (size + 2) is what gets centered.
---@return { width: integer, height: integer, row: integer, col: integer }
function M.dimensions()
  local columns = vim.o.columns
  local usable = vim.o.lines - vim.o.cmdheight
  local width = math.floor(columns * 0.8)
  local height = math.floor(usable * 0.8)
  return {
    width = width,
    height = height,
    row = math.floor((usable - height - 2) / 2),
    col = math.floor((columns - width - 2) / 2),
  }
end

---@return boolean
function M.is_open()
  return preview_win ~= nil and vim.api.nvim_win_is_valid(preview_win)
end

---Closing the focused float returns Neovim to the previous window, which is
---the window the preview was opened from.
function M.close()
  local win = preview_win
  preview_win = nil
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

---Line counter shown at the bottom right of the border, e.g. " 12 / 340 ".
---@param line integer
---@param total integer
---@return string
local function footer(line, total)
  return string.format(" %d / %d ", line, total)
end

---@param lines string[]
---@param highlights mdp.Highlight[]
---@return integer winid
function M.open(lines, highlights)
  M.close()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, hl in ipairs(highlights) do
    local end_col = hl.end_col == -1 and #lines[hl.row + 1] or hl.end_col
    vim.api.nvim_buf_set_extmark(
      buf,
      ns,
      hl.row,
      hl.col,
      { end_col = end_col, hl_group = hl.group, priority = hl.priority }
    )
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown_panel"

  local dims = M.dimensions()
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = dims.width,
    height = dims.height,
    row = dims.row,
    col = dims.col,
    border = "rounded",
    footer = footer(1, #lines),
    footer_pos = "right",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false
  vim.wo[win].list = false
  vim.wo[win].colorcolumn = ""
  vim.wo[win].foldcolumn = "0"
  vim.api.nvim_win_call(win, function()
    vim.opt_local.fillchars:append({ eob = " " })
  end)
  vim.wo[win].winhighlight =
    "NormalFloat:MarkdownPanelNormal,FloatBorder:MarkdownPanelBorder,FloatFooter:MarkdownPanelFooter"
  preview_win = win

  vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true, desc = "Close markdown panel" })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        local line = vim.api.nvim_win_get_cursor(win)[1]
        vim.api.nvim_win_set_config(win, { footer = footer(line, #lines), footer_pos = "right" })
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      M.close()
    end,
  })

  return win
end

return M
