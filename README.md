# markdown-panel

Preview markdown inside Neovim. `:MarkdownPanel` opens a centered, read-only floating window with the current buffer rendered: headings, emphasis, links, lists, task lists, code blocks with syntax highlight, quotes, rules and GFM tables. `q` closes it.

Pure Lua on top of the treesitter `markdown` and `markdown_inline` parsers that ship with Neovim. No browser, no external binary.

## Requirements

- Neovim >= 0.10

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "LeonardoBringel/nvim-markdown-panel-plugin",
  ft = "markdown",
  opts = {},
}
```

For a local clone, replace the first line with `dir = "~/path/to/nvim-markdown-panel-plugin"`.

The plugin has no `plugin/` directory. Its only auto-loaded file is `ftplugin/markdown.lua`, so nothing loads before the first markdown buffer, with or without `ft = "markdown"`.

## Usage

In a markdown buffer:

| Action | Effect |
| ------ | ------ |
| `:MarkdownPanel` or `<leader>mp` | Open the preview of the current buffer, unsaved changes included |
| `q` in the preview | Close it and return to the source window |
| Leaving the preview window | Closes it |

The command and the keymap are buffer-local and exist only in markdown buffers. From Lua: `require("markdown_panel").open()` and `require("markdown_panel").close()`.

The preview opens centered on the line that matches the cursor line in the source. A source line with no output of its own (a code fence, the frontmatter, a setext underline) opens at the next rendered line.

The footer, at the bottom-right of the border, shows the current line and the total number of lines, e.g. ` 12 / 340 `; these count lines of the rendered preview, not of the source file, since tables and other elements can add lines.

## Configuration

`setup()` is optional. These are the defaults:

```lua
require("markdown_panel").setup({
  -- Normal-mode key that opens the preview. false disables the mapping.
  keymap = "<leader>mp",
})
```

## Highlight groups

All groups are defined with `default = true`, so a colorscheme or your config can override them.

| Group | Default link |
| ----- | ------------ |
| `MarkdownPanelH1` … `MarkdownPanelH6` | `@markup.heading.1.markdown` … `@markup.heading.6.markdown` |
| `MarkdownPanelBold` | `@markup.strong` |
| `MarkdownPanelItalic` | `@markup.italic` |
| `MarkdownPanelStrike` | `@markup.strikethrough` |
| `MarkdownPanelCode` | `@markup.raw` |
| `MarkdownPanelCodeBlock` | `@markup.raw.block` |
| `MarkdownPanelLink` | `@markup.link.label` |
| `MarkdownPanelBullet` | `@markup.list` |
| `MarkdownPanelQuote` | `@markup.quote` |
| `MarkdownPanelRule` | `@punctuation.special` |
| `MarkdownPanelTableHeader` | `@markup.heading` |
| `MarkdownPanelTableBorder` | `@punctuation.special` |
| `MarkdownPanelChecked` | `@markup.list.checked` |
| `MarkdownPanelUnchecked` | `@markup.list.unchecked` |
| `MarkdownPanelNormal` | `Normal` |
| `MarkdownPanelBorder` | `Normal` |
| `MarkdownPanelFooter` | `Normal` |
| `MarkdownPanelBackdrop` | `bg = #000000`, `blend = 40` |

While the panel is open, a backdrop dims the rest of the editor behind it, lazy.nvim-style. Its `blend` works like `winblend`: higher is lighter, and `blend = 100` turns the effect off. Defining the group without `bg` dims only the text and keeps a transparent background, useful with a transparent `Normal`:

```lua
vim.api.nvim_set_hl(0, "MarkdownPanelBackdrop", { blend = 40 })
```

To change the darkening color or intensity instead:

```lua
vim.api.nvim_set_hl(0, "MarkdownPanelBackdrop", { bg = "#000000", blend = 60 })
```

The preview buffer has `filetype=markdown_panel`, so `FileType markdown_panel` autocmds can customize it further.

## Development

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (busted) in headless Neovim. Lint uses lua-language-server.

```bash
make test
```

| Target | What it runs |
| ------ | ------------ |
| `make deps` | Clones plenary.nvim into `.tests/deps` |
| `make test-unit` | `tests/unit` (pure renderer, config, highlights) |
| `make test` | All of `tests/`, integration included |
| `make lint` | `lua-language-server --check .` |

To reuse an installed plenary instead of cloning it, set `PLENARY_DIR`, for example `PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim make test`. The targets point the `XDG_*` directories at `.tests/xdg`, so tests never touch your own Neovim state.
