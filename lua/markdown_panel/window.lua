---@class mdp.Highlight
---@field row integer 0-based output line
---@field col integer 0-based byte, inclusive
---@field end_col integer byte, exclusive; -1 = to end of line
---@field group string

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
    vim.api.nvim_buf_set_extmark(buf, ns, hl.row, hl.col, { end_col = end_col, hl_group = hl.group })
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
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  preview_win = win

  vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true, desc = "Close markdown panel" })
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
