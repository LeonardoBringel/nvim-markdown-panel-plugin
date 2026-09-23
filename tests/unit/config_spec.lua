local function fresh_config()
  package.loaded["markdown_panel.config"] = nil
  return require("markdown_panel.config")
end

describe("markdown_panel.config", function()
  it("get() without setup() returns the default keymap", function()
    local config = fresh_config()
    assert.are.same({ keymap = "<leader>mp" }, config.get())
  end)

  it("setup() merges opts, and the last call wins restarting from defaults", function()
    local config = fresh_config()
    config.setup({ keymap = "<leader>x" })
    assert.are.equal("<leader>x", config.get().keymap)

    config.setup({})
    assert.are.equal("<leader>mp", config.get().keymap)
  end)

  it("setup({ keymap = false }) disables the keymap", function()
    local config = fresh_config()
    config.setup({ keymap = false })
    assert.are.equal(false, config.get().keymap)
  end)

  it("setup({ keymap = 42 }) notifies ERROR with the exact spec message and falls back to the default", function()
    local config = fresh_config()
    local notify_calls = {}
    local original_notify = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = msg, level = level })
    end

    config.setup({ keymap = 42 })

    vim.notify = original_notify

    assert.are.equal(1, #notify_calls)
    assert.are.equal('markdown-panel: invalid "keymap" option: expected string or false', notify_calls[1].msg)
    assert.are.equal(vim.log.levels.ERROR, notify_calls[1].level)
    assert.are.equal("<leader>mp", config.get().keymap)
  end)
end)
