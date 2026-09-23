local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local plenary = os.getenv("PLENARY_DIR") or (root .. "/.tests/deps/plenary.nvim")

vim.opt.runtimepath:prepend(plenary)
vim.opt.runtimepath:prepend(root)
vim.opt.swapfile = false

vim.cmd("filetype plugin on")
vim.cmd("runtime plugin/plenary.vim")
