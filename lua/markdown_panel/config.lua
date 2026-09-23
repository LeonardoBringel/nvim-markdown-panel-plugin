---@class mdp.Config
---@field keymap string|false

local M = {}

local defaults = {
  keymap = "<leader>mp",
}

---@type mdp.Config
local state = vim.deepcopy(defaults)

---@param opts table|nil
function M.setup(opts)
  opts = opts or {}

  local keymap = defaults.keymap
  if opts.keymap ~= nil then
    if type(opts.keymap) == "string" or opts.keymap == false then
      keymap = opts.keymap
    else
      vim.notify('markdown-panel: invalid "keymap" option: expected string or false', vim.log.levels.ERROR)
    end
  end

  state = { keymap = keymap }
end

---@return mdp.Config
function M.get()
  return state
end

return M
