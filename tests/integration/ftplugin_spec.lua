local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local ftplugin = root .. "/ftplugin/markdown.lua"

---@return integer[]
local function floats()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
  end, vim.api.nvim_list_wins())
end

---A fresh config module, as if setup() had never been called in this session.
local function reset_config()
  package.loaded["markdown_panel.config"] = nil
end

---@param lines string[]
---@return integer
local function markdown_buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  return buf
end

---Every buffer-local mapping of `buf`, as "mode lhs" strings, sorted.
---@param buf integer
---@return string[]
local function buffer_maps(buf)
  local out = {}
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      out[#out + 1] = mode .. " " .. map.lhs
    end
  end
  table.sort(out)
  return out
end

---Buffer-local user commands of `buf`, by name.
---@param buf integer
---@return table<string, table>
local function buffer_commands(buf)
  return vim.api.nvim_buf_get_commands(buf, {})
end

local leader = vim.g.mapleader or "\\"

describe("ftplugin/markdown.lua", function()
  before_each(function()
    vim.cmd("silent! only")
    reset_config()
  end)

  after_each(function()
    require("markdown_panel").close()
    for _, win in ipairs(floats()) do
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("silent! %bwipeout!")
    reset_config()
  end)

  it("maps <leader>mp buffer-locally without setup(), and it opens the preview (MDP-05, MDP-33)", function()
    local buf = markdown_buffer({ "# Hello" })

    local map = vim.fn.maparg("<leader>mp", "n", false, true)
    assert.are.equal(1, map.buffer)
    assert.is_function(map.callback)
    local other = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_call(other, function()
      assert.are.equal("", vim.fn.maparg("<leader>mp", "n"))
    end)

    vim.api.nvim_set_current_buf(buf)
    map.callback()

    assert.are.equal(1, #floats())
    assert.are.equal(floats()[1], vim.api.nvim_get_current_win())
    assert.are.same({ "Hello" }, vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false))
  end)

  it("maps the key given in setup({ keymap = ... }) (MDP-05)", function()
    require("markdown_panel").setup({ keymap = "<leader>zz" })
    markdown_buffer({ "# Hello" })

    assert.are.equal(1, vim.fn.maparg("<leader>zz", "n", false, true).buffer)
    assert.are.equal("", vim.fn.maparg("<leader>mp", "n"))
  end)

  it("creates no mapping at all with setup({ keymap = false }) (MDP-06)", function()
    -- Baseline: what a markdown buffer gets with a string keymap, minus that one mapping.
    require("markdown_panel").setup({ keymap = "<leader>zz" })
    local with_key = buffer_maps(markdown_buffer({ "a" }))
    local expected = vim.tbl_filter(function(m)
      return m ~= "n " .. leader .. "zz"
    end, with_key)
    assert.are.equal(#with_key - 1, #expected)

    require("markdown_panel").setup({ keymap = false })
    local buf = markdown_buffer({ "a" })

    assert.are.same(expected, buffer_maps(buf))
    assert.are.equal("", vim.fn.maparg("<leader>mp", "n"))
    -- The command still exists: only the keymap is disabled.
    assert.is_not_nil(buffer_commands(buf).MarkdownPanel)
  end)

  it("defines :MarkdownPanel only in the markdown buffer, and it opens the preview (MDP-31)", function()
    local other = vim.api.nvim_create_buf(true, false)
    local buf = markdown_buffer({ "**b**" })

    assert.is_not_nil(buffer_commands(buf).MarkdownPanel)
    assert.is_nil(buffer_commands(other).MarkdownPanel)
    assert.is_nil(vim.api.nvim_get_commands({}).MarkdownPanel)

    vim.cmd("MarkdownPanel")

    assert.are.equal(1, #floats())
    assert.are.same({ "b" }, vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false))
  end)

  it("sourcing the ftplugin twice in the same buffer does not register command or keymap again", function()
    local buf = markdown_buffer({ "a" })
    local maps_before = buffer_maps(buf)
    local commands_before = vim.tbl_keys(vim.api.nvim_buf_get_commands(buf, {}))

    -- lazy.nvim re-triggers FileType after setup(): a changed keymap must not add a second mapping.
    require("markdown_panel").setup({ keymap = "<leader>zz" })
    vim.cmd.source(vim.fn.fnameescape(ftplugin))
    vim.bo[buf].filetype = "markdown"

    assert.are.same(maps_before, buffer_maps(buf))
    assert.are.same(commands_before, vim.tbl_keys(vim.api.nvim_buf_get_commands(buf, {})))
    assert.are.equal(1, vim.fn.maparg("<leader>mp", "n", false, true).buffer)
    assert.are.equal("", vim.fn.maparg("<leader>zz", "n"))
  end)
end)

describe("lazy loading in a clean child nvim", function()
  local result

  ---Runs a `nvim --headless --clean` with only this repo added to the
  ---runtimepath, drives it through a .txt and a .md buffer and returns
  ---what it observed (decoded from its stdout).
  local function child()
    if result then
      return result
    end
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ "plain text" }, dir .. "/x.txt")
    vim.fn.writefile({ "# Hi" }, dir .. "/y.md")
    local script = dir .. "/probe.lua"
    vim.fn.writefile({
      "local function loaded()",
      "  local names = {}",
      "  for name in pairs(package.loaded) do",
      "    if name:match('^markdown_panel') then names[#names + 1] = name end",
      "  end",
      "  table.sort(names)",
      "  return names",
      "end",
      "local out = { at_startup = loaded() }",
      ("vim.cmd.edit(%q)"):format(dir .. "/x.txt"),
      "local txt = vim.api.nvim_get_current_buf()",
      "out.txt_filetype = vim.bo[txt].filetype",
      "out.after_txt = loaded()",
      "local ok, err = pcall(vim.cmd, 'MarkdownPanel')",
      "out.txt_command = { ok = ok, err = tostring(err) }",
      ("vim.cmd.edit(%q)"):format(dir .. "/y.md"),
      "local md = vim.api.nvim_get_current_buf()",
      "out.md_filetype = vim.bo[md].filetype",
      "out.md_has_command = vim.api.nvim_buf_get_commands(md, {}).MarkdownPanel ~= nil",
      "out.txt_has_command = vim.api.nvim_buf_get_commands(txt, {}).MarkdownPanel ~= nil",
      "out.global_command = vim.api.nvim_get_commands({}).MarkdownPanel ~= nil",
      "out.md_keymap_buffer = vim.fn.maparg('<leader>mp', 'n', false, true).buffer",
      "vim.cmd('MarkdownPanel')",
      "local win = vim.api.nvim_get_current_win()",
      "out.preview_relative = vim.api.nvim_win_get_config(win).relative",
      "out.preview_lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)",
      "io.stdout:write(vim.json.encode(out))",
    }, script)

    local xdg = root .. "/.tests/xdg-child"
    local env = {}
    for _, kind in ipairs({ "CONFIG", "DATA", "STATE", "CACHE" }) do
      env["XDG_" .. kind .. "_HOME"] = xdg .. "/" .. kind:lower()
      vim.fn.mkdir(env["XDG_" .. kind .. "_HOME"], "p")
    end
    local proc = vim
      .system({
        vim.v.progpath,
        "--headless",
        "--clean",
        "--cmd",
        "set runtimepath^=" .. vim.fn.fnameescape(root),
        "-c",
        "filetype plugin on",
        "-c",
        "luafile " .. vim.fn.fnameescape(script),
        "-c",
        "qa!",
      }, { env = env, text = true, timeout = 20000 })
      :wait()
    vim.fn.delete(dir, "rf")
    assert.are.equal(0, proc.code, proc.stderr)
    result = vim.json.decode(proc.stdout)
    return result
  end

  it("loads no markdown_panel module before a markdown buffer is opened (MDP-30)", function()
    local out = child()
    assert.are.equal("text", out.txt_filetype)
    assert.are.same({}, out.at_startup)
    assert.are.same({}, out.after_txt)
  end)

  it("defines :MarkdownPanel in the markdown buffer only, never globally (MDP-31)", function()
    local out = child()
    assert.are.equal("markdown", out.md_filetype)
    assert.is_true(out.md_has_command)
    assert.is_false(out.txt_has_command)
    assert.is_false(out.global_command)
  end)

  it(":MarkdownPanel in the .txt buffer fails with E492 (MDP-32)", function()
    local out = child()
    assert.is_false(out.txt_command.ok)
    assert.is_truthy(out.txt_command.err:find("E492: Not an editor command", 1, true))
  end)

  it("works with defaults and without setup(): keymap mapped, :MarkdownPanel opens the preview (MDP-33)", function()
    local out = child()
    assert.are.equal(1, out.md_keymap_buffer)
    assert.are.equal("editor", out.preview_relative)
    assert.are.same({ "Hi" }, out.preview_lines)
  end)
end)
