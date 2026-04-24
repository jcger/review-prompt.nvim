# review-prompt.nvim

Collect code review comments while reading a diff, then export them as a single AI-ready prompt. Zero dependencies — works out of the box, and plays nicely with UI plugins like [dressing.nvim](https://github.com/stevearc/dressing.nvim) or [snacks.nvim](https://github.com/folke/snacks.nvim) that override `vim.ui.select`.

## Features

- Add a comment at the current line (normal mode) or over a visual range
- Inline virtual text annotation on every commented line
- Manage comments with a two-step picker: jump to, delete, or edit any entry
- Export all comments as a single AI-addressed prompt and auto-clear
- Comments persist across restarts, scoped to the current git repository
- Fully configurable keymaps — or disable them entirely and use the Lua API

## Requirements

- Neovim >= 0.9

## Installation

**lazy.nvim** (zero-config):
```lua
{ "jcger/review-prompt.nvim" }
```

**lazy.nvim** (with options):
```lua
{
  "jcger/review-prompt.nvim",
  opts = {
    keymaps = {
      add    = "<leader>rc",
      manage = "<leader>rl",
      export = "<leader>ry",
    },
    highlight = "DiagnosticWarn",
  },
}
```

**packer.nvim**:
```lua
use "jcger/review-prompt.nvim"
```

**vim-plug**:
```vim
Plug 'jcger/review-prompt.nvim'
```

## Keymaps

| Key          | Mode  | Action                                               |
|--------------|-------|------------------------------------------------------|
| `<leader>rc` | n / v | Add comment at cursor (visual: uses selected range)  |
| `<leader>rl` | n     | Manage comments — select entry → Jump / Delete / Edit |
| `<leader>ry` | n     | Copy all as AI prompt, then auto-clear               |

All keys are configurable. Set any keymap to `false` to disable it.

## Exported prompt format

`<leader>ry` copies to the system clipboard (`+` register):

```
Please address the following code review comments:

/abs/path/to/src/api/handler.ts:42
Comment: fix the off-by-one error here

/abs/path/to/src/utils/helpers.ts:100-110
Comment: extract this block into a helper function
```

## Configuration

```lua
require("review-prompt").setup({
  keymaps = {
    add    = "<leader>rc",  -- n + v
    manage = "<leader>rl",  -- n
    export = "<leader>ry",  -- n; set to false to disable
  },
  -- stdpath("data")/review-prompt/<repo-slug>.json
  data_dir  = vim.fn.stdpath("data") .. "/review-prompt",
  -- any highlight group to link ReviewComment virtual text to
  highlight = "DiagnosticWarn",
})
```

## Persistence

Comments are saved to `{data_dir}/<repo-slug>.json` on every mutation. The slug is the sanitized basename of `git rev-parse --show-toplevel`, so comments are isolated per repository. When not inside a git repo, `global.json` is used. The list is loaded on `VimEnter` and reloaded on `VimResume` (returning from a shell via `:!` or a terminal multiplexer).

## Lua API

All operations are exposed if you prefer to define your own keymaps:

```lua
local rc = require("review-prompt")
rc.add_comment()
rc.manage_comments()
rc.copy_and_clear()
```

## License

MIT
