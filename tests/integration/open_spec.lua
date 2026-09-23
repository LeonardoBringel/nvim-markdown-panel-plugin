local panel = require("markdown_panel")

local ns = vim.api.nvim_create_namespace("markdown_panel")

---@return integer[]
local function floats()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
  end, vim.api.nvim_list_wins())
end

---@param lines string[]
---@param filetype string
---@return integer
local function scratch(lines, filetype)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype
  return buf
end

---@param win integer
---@return string[]
local function win_lines(win)
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
end

describe("markdown_panel.open()", function()
  local notify_calls
  local original_notify = vim.notify
  local origin_win

  before_each(function()
    vim.cmd("silent! only")
    origin_win = vim.api.nvim_get_current_win()
    notify_calls = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = original_notify
    panel.close()
    for _, win in ipairs(floats()) do
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("silent! %bwipeout!")
  end)

  it("renders the current buffer content, including unsaved changes (MDP-02)", function()
    local path = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ "# Saved" }, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    local source = vim.api.nvim_get_current_buf()
    assert.are.equal("markdown", vim.bo[source].filetype)
    vim.api.nvim_buf_set_lines(source, 0, -1, false, { "# T" })
    assert.is_true(vim.bo[source].modified)

    panel.open()

    assert.are.equal(1, #floats())
    local win = floats()[1]
    assert.are.equal(win, vim.api.nvim_get_current_win())
    assert.are.same({ "T" }, win_lines(win))
    local marks = vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(win), ns, 0, -1, { details = true })
    assert.are.equal(1, #marks)
    assert.are.same({ 0, 0, 0, 1, "MarkdownPanelH1" }, {
      marks[1][2],
      marks[1][3],
      marks[1][4].end_row,
      marks[1][4].end_col,
      marks[1][4].hl_group,
    })
    -- The highlight group must be defined for the extmark to show anything.
    assert.are.equal("@markup.heading.1.markdown", vim.api.nvim_get_hl(0, { name = "MarkdownPanelH1" }).link)
    assert.are.same({}, notify_calls)
    vim.fn.delete(path)
  end)

  it("opens the buffer given as argument", function()
    local target = scratch({ "# Other" }, "markdown")
    scratch({ "# Current" }, "markdown")

    panel.open(target)

    assert.are.equal(1, #floats())
    assert.are.same({ "Other" }, win_lines(floats()[1]))
  end)

  it("shows the single line (empty document) when all source lines are blank (MDP-07)", function()
    scratch({ "", "  " }, "markdown")

    panel.open()

    assert.are.equal(1, #floats())
    assert.are.same({ "(empty document)" }, win_lines(floats()[1]))
    assert.are.same({}, notify_calls)
  end)

  for _, lang in ipairs({ "markdown", "markdown_inline" }) do
    it(("notifies ERROR and opens no window when the %s parser is missing (MDP-43)"):format(lang), function()
      scratch({ "# T" }, "markdown")
      local wins_before = vim.api.nvim_list_wins()
      local original_add = vim.treesitter.language.add
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.treesitter.language.add = function(name, ...)
        if name == lang then
          error("no parser for " .. name)
        end
        return original_add(name, ...)
      end

      local result = { pcall(panel.open) }
      vim.treesitter.language.add = original_add

      assert.are.same({ true }, result) -- no error raised
      assert.are.same({
        { msg = ('markdown-panel: treesitter parser "%s" not found'):format(lang), level = vim.log.levels.ERROR },
      }, notify_calls)
      assert.are.same(wins_before, vim.api.nvim_list_wins())
      assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    end)
  end

  it("notifies ERROR and opens no window on Neovim older than 0.10 (MDP-44)", function()
    scratch({ "# T" }, "markdown")
    local wins_before = vim.api.nvim_list_wins()
    local original_has = vim.fn.has
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.has = function(feature)
      if feature == "nvim-0.10" then
        return 0
      end
      return original_has(feature)
    end

    local result = { pcall(panel.open) }
    vim.fn.has = original_has

    assert.are.same({ true }, result) -- no error raised
    assert.are.same({ { msg = "markdown-panel: requires Neovim >= 0.10", level = vim.log.levels.ERROR } }, notify_calls)
    assert.are.same(wins_before, vim.api.nvim_list_wins())
  end)

  it("notifies WARN and opens no window on a non-markdown buffer (MDP-45)", function()
    scratch({ "local x = 1" }, "lua")
    local wins_before = vim.api.nvim_list_wins()

    local result = { pcall(panel.open) }

    assert.are.same({ true }, result) -- no error raised
    assert.are.same({ { msg = "markdown-panel: current buffer is not markdown", level = vim.log.levels.WARN } }, notify_calls)
    assert.are.same(wins_before, vim.api.nvim_list_wins())
  end)

  it("close() closes the open preview and returns focus to the source window", function()
    local source = scratch({ "# T" }, "markdown")
    panel.open()
    assert.are.equal(1, #floats())

    panel.close()

    assert.are.same({}, floats())
    assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    assert.are.equal(source, vim.api.nvim_get_current_buf())
  end)

  it("setup() forwards options to the config module", function()
    panel.setup({ keymap = "<leader>x" })
    assert.are.equal("<leader>x", require("markdown_panel.config").get().keymap)
    panel.setup({})
    assert.are.equal("<leader>mp", require("markdown_panel.config").get().keymap)
  end)
end)
