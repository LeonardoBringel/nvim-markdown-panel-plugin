local window = require("markdown_panel.window")

local ns = vim.api.nvim_create_namespace("markdown_panel")

---@return integer[]
local function floats()
  return vim.tbl_filter(function(win)
    local cfg = vim.api.nvim_win_get_config(win)
    return cfg.relative ~= "" and cfg.focusable
  end, vim.api.nvim_list_wins())
end

---Windows showing a backdrop buffer, found by its filetype.
---@return integer[]
local function backdrops()
  return vim.tbl_filter(function(win)
    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "markdown_panel_backdrop"
  end, vim.api.nvim_list_wins())
end

---@param keys string
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

---Values restored on the source window after each test.
local source_defaults = {
  wrap = true,
  linebreak = false,
  number = false,
  relativenumber = false,
  cursorline = false,
  signcolumn = "auto",
  winhighlight = "",
  spell = false,
  list = false,
  colorcolumn = "",
  foldcolumn = "0",
  fillchars = "",
}

---Decorations the panel must not inherit from the source window (VIS-07..VIS-11).
local function decorate_source(win)
  vim.wo[win].spell = true
  vim.wo[win].list = true
  vim.wo[win].colorcolumn = "80"
  vim.wo[win].foldcolumn = "2"
  vim.wo[win].fillchars = "fold:-"
end

describe("markdown_panel.window", function()
  local origin_win, source_buf

  before_each(function()
    vim.o.columns = 100
    vim.o.lines = 40
    vim.o.cmdheight = 1
    vim.cmd("silent! only")
    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(source_buf)
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, { "# Title", "body" })
    origin_win = vim.api.nvim_get_current_win()
  end)

  after_each(function()
    window.close()
    for _, win in ipairs(floats()) do
      vim.api.nvim_win_close(win, true)
    end
    vim.api.nvim_buf_delete(source_buf, { force = true })
    for name, value in pairs(source_defaults) do
      vim.wo[origin_win][name] = value
    end
  end)

  describe("dimensions()", function()
    it("is 80% of columns and of lines minus cmdheight, centered", function()
      assert.are.same({ width = 80, height = 31, row = 3, col = 9 }, window.dimensions())
    end)

    it("floors fractional sizes", function()
      vim.o.columns = 99
      vim.o.lines = 30
      vim.o.cmdheight = 2
      -- width floor(79.2) = 79, height floor(0.8 * 28) = floor(22.4) = 22
      local dims = window.dimensions()
      assert.are.equal(79, dims.width)
      assert.are.equal(22, dims.height)
    end)
  end)

  describe("open()", function()
    it("opens a rounded editor-relative float with the computed size and focuses it (MDP-01)", function()
      local win = window.open({ "hello" }, {})
      local cfg = vim.api.nvim_win_get_config(win)
      assert.are.equal("editor", cfg.relative)
      assert.are.equal(80, cfg.width)
      assert.are.equal(31, cfg.height)
      assert.are.equal(3, cfg.row)
      assert.are.equal(9, cfg.col)
      assert.are.same({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, cfg.border)
      assert.are.equal(win, vim.api.nvim_get_current_win())
      assert.is_true(window.is_open())
    end)

    it("writes the given lines into the preview buffer", function()
      local win = window.open({ "Title", "", "  code" }, {})
      local buf = vim.api.nvim_win_get_buf(win)
      assert.are.same({ "Title", "", "  code" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("creates a read-only scratch buffer with filetype markdown_panel (MDP-03)", function()
      local buf = vim.api.nvim_win_get_buf(window.open({ "x" }, {}))
      assert.is_false(vim.bo[buf].modifiable)
      assert.are.equal("nofile", vim.bo[buf].buftype)
      assert.are.equal("wipe", vim.bo[buf].bufhidden)
      assert.is_false(vim.bo[buf].swapfile)
      assert.are.equal("markdown_panel", vim.bo[buf].filetype)
      local ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, { "changed" })
      assert.is_false(ok)
    end)

    it("sets wrap, linebreak, no numbers and signcolumn=no on the window (MDP-04)", function()
      -- Floats inherit window-local options from the origin; start from the opposite values.
      vim.wo[origin_win].wrap = false
      vim.wo[origin_win].linebreak = false
      vim.wo[origin_win].number = true
      vim.wo[origin_win].relativenumber = true
      vim.wo[origin_win].signcolumn = "yes"
      local win = window.open({ "x" }, {})
      assert.is_true(vim.wo[win].wrap)
      assert.is_true(vim.wo[win].linebreak)
      assert.is_false(vim.wo[win].number)
      assert.is_false(vim.wo[win].relativenumber)
      assert.are.equal("no", vim.wo[win].signcolumn)
    end)

    it("maps NormalFloat, FloatBorder and FloatFooter to the panel groups (VIS-03)", function()
      local win = window.open({ "x" }, {})
      assert.are.equal(
        "NormalFloat:MarkdownPanelNormal,FloatBorder:MarkdownPanelBorder,FloatFooter:MarkdownPanelFooter",
        vim.wo[win].winhighlight
      )
    end)

    it("keeps the rounded border and has no title (VIS-05)", function()
      local cfg = vim.api.nvim_win_get_config(window.open({ "x" }, {}))
      assert.are.same({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, cfg.border)
      assert.is_nil(cfg.title)
    end)

    it("leaves the source window winhighlight unchanged after close (VIS-06)", function()
      vim.wo[origin_win].winhighlight = "Normal:Comment"
      window.open({ "x" }, {})
      window.close()
      assert.are.equal("Normal:Comment", vim.wo[origin_win].winhighlight)
    end)

    it("turns spell off when the source window has spell on (VIS-07)", function()
      decorate_source(origin_win)
      local win = window.open({ "x" }, {})
      assert.is_false(vim.wo[win].spell)
    end)

    it("turns list off when the source window has list on (VIS-08)", function()
      decorate_source(origin_win)
      local win = window.open({ "x" }, {})
      assert.is_false(vim.wo[win].list)
    end)

    it("clears colorcolumn when the source window has colorcolumn=80 (VIS-09)", function()
      decorate_source(origin_win)
      local win = window.open({ "x" }, {})
      assert.are.equal("", vim.wo[win].colorcolumn)
    end)

    it("sets foldcolumn=0 when the source window has foldcolumn=2 (VIS-10)", function()
      decorate_source(origin_win)
      local win = window.open({ "x" }, {})
      assert.are.equal("0", vim.wo[win].foldcolumn)
    end)

    it("adds eob: to fillchars when the source window already has fold:- (VIS-11)", function()
      decorate_source(origin_win)
      local win = window.open({ "x" }, {})
      local fillchars = vim.split(vim.wo[win].fillchars, ",")
      assert.is_true(vim.tbl_contains(fillchars, "eob: "))
    end)

    it("leaves spell, list, colorcolumn, foldcolumn and fillchars of the source window unchanged after close (VIS-12)", function()
      decorate_source(origin_win)
      local names = { "spell", "list", "colorcolumn", "foldcolumn", "fillchars" }
      local before = {}
      for _, name in ipairs(names) do
        before[name] = vim.wo[origin_win][name]
      end
      window.open({ "x" }, {})
      window.close()
      local after = {}
      for _, name in ipairs(names) do
        after[name] = vim.wo[origin_win][name]
      end
      assert.are.same(before, after)
    end)

    it("opens with the footer at 1 / N aligned right (VIS-15)", function()
      local cfg = vim.api.nvim_win_get_config(window.open({ "a", "b", "c" }, {}))
      assert.are.same({ { " 1 / 3 " } }, cfg.footer)
      assert.are.equal("right", cfg.footer_pos)
    end)

    it("shows 1 / 1 for a single-line preview (VIS-15 edge case)", function()
      local cfg = vim.api.nvim_win_get_config(window.open({ "(empty document)" }, {}))
      assert.are.same({ { " 1 / 1 " } }, cfg.footer)
    end)

    it("counts the total from the panel buffer line count (VIS-15)", function()
      -- An empty list still leaves the buffer with one line.
      local win = window.open({}, {})
      assert.are.same({ { " 1 / 1 " } }, vim.api.nvim_win_get_config(win).footer)
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = vim.api.nvim_win_get_buf(win) })
      assert.are.same({ { " 1 / 1 " } }, vim.api.nvim_win_get_config(win).footer)
    end)

    it("updates the footer to the cursor line on CursorMoved (VIS-16)", function()
      local win = window.open({ "a", "b", "c" }, {})
      local buf = vim.api.nvim_win_get_buf(win)
      assert.are.equal(1, #vim.api.nvim_get_autocmds({ event = "CursorMoved", buffer = buf }))
      -- Headless Neovim does not fire CursorMoved from feedkeys; fire it after moving.
      press("j")
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
      assert.are.same({ { " 2 / 3 " } }, vim.api.nvim_win_get_config(win).footer)
      press("G")
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
      assert.are.same({ { " 3 / 3 " } }, vim.api.nvim_win_get_config(win).footer)
    end)

    it("keeps the rounded border and footer_pos right after a footer update (VIS-17)", function()
      local win = window.open({ "a", "b", "c" }, {})
      press("G")
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = vim.api.nvim_win_get_buf(win) })
      local cfg = vim.api.nvim_win_get_config(win)
      assert.are.same({ { " 3 / 3 " } }, cfg.footer)
      assert.are.same({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, cfg.border)
      assert.are.equal("right", cfg.footer_pos)
    end)

    it("turns highlights into extmarks in the markdown_panel namespace", function()
      local win = window.open({ "Title", "- item" }, {
        { row = 0, col = 0, end_col = -1, group = "MarkdownPanelH1" },
        { row = 1, col = 0, end_col = 1, group = "MarkdownPanelBullet" },
      })
      local buf = vim.api.nvim_win_get_buf(win)
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
      assert.are.equal(2, #marks)
      -- mark = { id, row, col, details }
      assert.are.same({ 0, 0, 0, 5, "MarkdownPanelH1" }, {
        marks[1][2],
        marks[1][3],
        marks[1][4].end_row,
        marks[1][4].end_col,
        marks[1][4].hl_group,
      })
      assert.are.same({ 1, 0, 1, 1, "MarkdownPanelBullet" }, {
        marks[2][2],
        marks[2][3],
        marks[2][4].end_row,
        marks[2][4].end_col,
        marks[2][4].hl_group,
      })
    end)

    it("gives an extmark the highlight's priority, or the default without one (MDP-41)", function()
      local win = window.open({ "  local x" }, {
        { row = 0, col = 0, end_col = -1, group = "MarkdownPanelCodeBlock" },
        { row = 0, col = 2, end_col = 7, group = "@keyword.lua", priority = 4196 },
      })
      local marks = vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(win), ns, 0, -1, { details = true })
      local priority = {}
      for _, mark in ipairs(marks) do
        priority[mark[4].hl_group] = mark[4].priority
      end
      -- 4096 is nvim_buf_set_extmark's default priority.
      assert.are.same({ MarkdownPanelCodeBlock = 4096, ["@keyword.lua"] = 4196 }, priority)
    end)

    it("maps q only in the preview buffer", function()
      local win = window.open({ "x" }, {})
      local map = vim.fn.maparg("q", "n", false, true)
      assert.are.equal(1, map.buffer)
      assert.are.equal(vim.api.nvim_win_get_buf(win), vim.api.nvim_get_current_buf())
      vim.api.nvim_buf_call(source_buf, function()
        assert.are.equal("", vim.fn.maparg("q", "n"))
      end)
    end)

    it("keeps at most one preview float when opened twice (MDP-12)", function()
      local first = window.open({ "one" }, {})
      local first_buf = vim.api.nvim_win_get_buf(first)
      local second = window.open({ "two" }, {})
      assert.are.same({ second }, floats())
      assert.is_false(vim.api.nvim_win_is_valid(first))
      assert.is_false(vim.api.nvim_buf_is_valid(first_buf))
      assert.are.same({ "two" }, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(second), 0, -1, false))
    end)

    it("closes a previous preview that lost focus without WinLeave (MDP-12)", function()
      local first = window.open({ "one" }, {})
      vim.cmd("noautocmd wincmd p")
      assert.is_true(vim.api.nvim_win_is_valid(first))
      local second = window.open({ "two" }, {})
      assert.is_false(vim.api.nvim_win_is_valid(first))
      assert.are.same({ second }, floats())
    end)
  end)

  describe("closing", function()
    it("q closes the float and returns focus to the origin window (MDP-08)", function()
      window.open({ "x" }, {})
      press("q")
      assert.are.same({}, floats())
      assert.are.equal(origin_win, vim.api.nvim_get_current_win())
      assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
      assert.is_false(window.is_open())
    end)

    it("q returns focus to the origin window after a second open (MDP-08, MDP-12)", function()
      window.open({ "one" }, {})
      window.open({ "two" }, {})
      press("q")
      assert.are.same({}, floats())
      assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    end)

    it("wipes the preview buffer once closed (MDP-09)", function()
      local buf = vim.api.nvim_win_get_buf(window.open({ "x" }, {}))
      press("q")
      assert.is_false(vim.api.nvim_buf_is_valid(buf))
    end)

    it("closes when focus leaves the float (MDP-10)", function()
      local win = window.open({ "x" }, {})
      local buf = vim.api.nvim_win_get_buf(win)
      vim.cmd.wincmd("p")
      assert.is_false(vim.api.nvim_win_is_valid(win))
      assert.is_false(vim.api.nvim_buf_is_valid(buf))
      assert.are.same({}, floats())
      assert.is_false(window.is_open())
      assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    end)

    it("closes and keeps focus where the user went when leaving to another split (MDP-10)", function()
      vim.cmd("vsplit")
      local other_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(origin_win)
      local win = window.open({ "x" }, {})
      vim.api.nvim_set_current_win(other_win)
      assert.is_false(vim.api.nvim_win_is_valid(win))
      assert.are.same({}, floats())
      assert.are.equal(other_win, vim.api.nvim_get_current_win())
    end)

    it("leaves no q mapping in the source buffer and q still records macros (MDP-11)", function()
      window.open({ "x" }, {})
      press("q")
      assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
      assert.are.equal("", vim.fn.maparg("q", "n"))
      press("qa")
      assert.are.equal("a", vim.fn.reg_recording())
      press("q")
      assert.are.equal("", vim.fn.reg_recording())
    end)

    it("close() after the window was closed with :close does not error", function()
      local win = window.open({ "x" }, {})
      vim.cmd("close")
      assert.is_false(vim.api.nvim_win_is_valid(win))
      assert.has_no_error(function()
        window.close()
      end)
      assert.is_false(window.is_open())
    end)

    it("close() after the float was closed from another window does not error", function()
      local win = window.open({ "x" }, {})
      vim.cmd("noautocmd wincmd p")
      vim.api.nvim_win_close(win, true)
      assert.has_no_error(function()
        window.close()
      end)
      assert.is_false(window.is_open())
    end)

    it("close() with nothing ever opened does not error", function()
      assert.has_no_error(function()
        window.close()
        window.close()
      end)
      assert.is_false(window.is_open())
    end)
  end)

  describe("backdrop", function()
    after_each(function()
      for _, win in ipairs(backdrops()) do
        vim.api.nvim_win_close(win, true)
      end
    end)

    it("opens an editor-sized, non-focusable float at zindex 49 below the panel's 50 (BKD-03)", function()
      local win = window.open({ "x" }, {})
      local found = backdrops()
      assert.are.equal(1, #found)
      local cfg = vim.api.nvim_win_get_config(found[1])
      assert.are.equal("editor", cfg.relative)
      assert.are.equal(0, cfg.row)
      assert.are.equal(0, cfg.col)
      assert.are.equal(100, cfg.width)
      assert.are.equal(40, cfg.height)
      assert.is_false(cfg.focusable)
      assert.are.equal(49, cfg.zindex)
      assert.are.equal(50, vim.api.nvim_win_get_config(win).zindex)
    end)

    it("maps Normal to MarkdownPanelBackdrop with winblend 40 (BKD-04)", function()
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      assert.are.equal("Normal:MarkdownPanelBackdrop", vim.wo[bd].winhighlight)
      assert.are.equal(40, vim.wo[bd].winblend)
    end)

    it("leaves the panel, not the backdrop, as the current window (BKD-05)", function()
      local win = window.open({ "x" }, {})
      local found = backdrops()
      assert.are.equal(1, #found)
      assert.are.equal(win, vim.api.nvim_get_current_win())
      assert.are_not.equal(found[1], vim.api.nvim_get_current_win())
    end)

    it("uses a nofile, wipe buffer with filetype markdown_panel_backdrop (BKD-06)", function()
      window.open({ "x" }, {})
      local buf = vim.api.nvim_win_get_buf(backdrops()[1])
      assert.are.equal("nofile", vim.bo[buf].buftype)
      assert.are.equal("wipe", vim.bo[buf].bufhidden)
      assert.are.equal("markdown_panel_backdrop", vim.bo[buf].filetype)
    end)

    it("does not inherit number, cursorline or eob from the origin window (BKD-13)", function()
      vim.wo[origin_win].number = true
      vim.wo[origin_win].cursorline = true
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      assert.is_false(vim.wo[bd].number)
      assert.is_false(vim.wo[bd].cursorline)
      assert.is_true(vim.tbl_contains(vim.split(vim.wo[bd].fillchars, ","), "eob: "))
    end)

    it("closes the backdrop and wipes its buffer when q closes the panel (BKD-07)", function()
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      local buf = vim.api.nvim_win_get_buf(bd)
      press("q")
      assert.is_false(vim.api.nvim_win_is_valid(bd))
      assert.is_false(vim.api.nvim_buf_is_valid(buf))
    end)

    it("closes the backdrop and wipes its buffer when focus leaves the panel (BKD-07)", function()
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      local buf = vim.api.nvim_win_get_buf(bd)
      vim.cmd.wincmd("p")
      assert.is_false(vim.api.nvim_win_is_valid(bd))
      assert.is_false(vim.api.nvim_buf_is_valid(buf))
    end)

    it("closes the backdrop when the panel is closed with :close (BKD-08)", function()
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      assert.is_true(vim.api.nvim_win_is_valid(bd))
      vim.cmd("close")
      assert.is_false(vim.api.nvim_win_is_valid(bd))
    end)

    it("closes the backdrop when the panel is closed with nvim_win_close from another window (BKD-08)", function()
      local win = window.open({ "x" }, {})
      local bd = backdrops()[1]
      vim.cmd("noautocmd wincmd p")
      vim.api.nvim_win_close(win, true)
      assert.is_false(vim.api.nvim_win_is_valid(bd))
    end)

    it("keeps exactly one backdrop when the panel is opened twice (BKD-09)", function()
      window.open({ "one" }, {})
      local first = backdrops()[1]
      window.open({ "two" }, {})
      assert.are.equal(1, #backdrops())
      assert.is_false(vim.api.nvim_win_is_valid(first))
    end)

    it("resizes to the new columns and lines on VimResized (BKD-10)", function()
      window.open({ "x" }, {})
      local bd = backdrops()[1]
      vim.o.columns = 120
      vim.o.lines = 50
      vim.api.nvim_exec_autocmds("VimResized", {})
      local cfg = vim.api.nvim_win_get_config(bd)
      assert.are.equal(120, cfg.width)
      assert.are.equal(50, cfg.height)
    end)

    it("leaves no VimResized autocmd after the panel closes (BKD-11)", function()
      window.open({ "x" }, {})
      local query = { event = "VimResized", group = "markdown_panel_backdrop" }
      assert.are.equal(1, #vim.api.nvim_get_autocmds(query))
      window.close()
      assert.are.same({}, vim.api.nvim_get_autocmds(query))
    end)

    it("leaves no VimResized autocmd after the panel is closed outside the plugin (BKD-11)", function()
      local win = window.open({ "x" }, {})
      local query = { event = "VimResized", group = "markdown_panel_backdrop" }
      assert.are.equal(1, #vim.api.nvim_get_autocmds(query))
      vim.cmd("noautocmd wincmd p")
      vim.api.nvim_win_close(win, true)
      assert.are.same({}, vim.api.nvim_get_autocmds(query))
    end)
  end)
end)
