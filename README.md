# review-prompt.nvim

Collect code review comments while reading a diff, then export them as a single AI-ready prompt. Zero dependencies.

The review keys follow [tuicr](https://github.com/agavra/tuicr): comment, move between notes, copy the review, and clear it only when you mean to.

## Features

- Comment on a line, a visual range, a whole file, or the review
- Multiline comment box, with optional comment types
- Inline virtual text on every commented line
- Summary list: jump, delete, edit, or copy one comment
- Copy the review without deleting it
- Opt-in review mode with tuicr's keys (`c`, `dd`, `y`, `m` / `M`, `?`)
- `:Review` commands with tab completion
- Comments persist across restarts, scoped to the current git repository

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
      mode   = "<leader>rr",
    },
    review_leader = ";",
    comment_types = { "issue", "suggestion", "note" },
    preamble = "Notes:",
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

These stay out of the way of normal editing:

| Key          | Mode  | Action                                      |
|--------------|-------|---------------------------------------------|
| `<leader>rc` | n / v | Comment on this line, or the visual range  |
| `<leader>rl` | n     | Open the summary                            |
| `<leader>ry` | n     | Copy the review to the clipboard            |
| `<leader>rr` | n     | Toggle review mode                          |

`<leader>ry` copies and leaves the comments in place. `:Review clip!` copies and then clears them.

Set any keymap to `false` to disable it.

### Review mode

`<leader>rr` or `:Review mode` turns on buffer-local tuicr keys. The statusline can show it with `%{v:lua.require('review-prompt').status()}`.

| Key   | Mode  | Action                                              |
|-------|-------|-----------------------------------------------------|
| `c`   | n / v | Comment on this line, or the visual selection       |
| `<CR>`| v     | Comment on the visual selection                     |
| `C`   | n     | Comment on this file                                |
| `;c`  | n     | Review-level note (no file)                         |
| `dd`  | n     | Delete the comment on this line                     |
| `i`   | n     | Edit the comment on this line                       |
| `A`   | n     | Edit it, cursor at the end                          |
| `y`   | n     | Copy the whole review                               |
| `Y`   | n     | Copy the comment on this line                       |
| `m` / `M` | n | Next / previous comment                          |
| `?`   | n     | Help                                                |

`;` is the review leader, so while review mode is on it waits briefly before repeating an `f` / `t` motion. Change it with `review_leader`.

File notes and review notes have no line to stand on. Edit those from the summary.

Several comments on one line: `dd`, `i`, and `Y` ask which one.

## Summary

`:Review` or `<leader>rl` opens the list.

| Key        | Action        |
|------------|---------------|
| `j` / `k`  | Move          |
| `Enter`    | Jump          |
| `dd`       | Delete        |
| `i` / `A`  | Edit          |
| `y`        | Copy that one |
| `Esc` / `q`| Close         |

## Comment box

`Enter` or `Ctrl-s` saves. `Ctrl-j` or `Shift-Enter` inserts a newline. `Esc` cancels. When `comment_types` is set, `Tab` and `Shift-Tab` cycle the type, and the export line is prefixed with `[issue]`.

## Commands

`:Review` completes the verb on Tab. A bang works as `:Review clip!` or `:Review! clip`.

| Command            | Action                                      |
|--------------------|---------------------------------------------|
| `:Review`          | Summary                                     |
| `:Review comment`  | Comment on this line, or the given range    |
| `:Review file`     | Comment on this file                        |
| `:Review note`     | Review-level note                           |
| `:Review delete`   | Delete the comment on this line             |
| `:Review edit`     | Edit the comment on this line               |
| `:Review clip`     | Copy the review                             |
| `:Review clip!`    | Copy the review and clear it                |
| `:Review yank`     | Copy the comment on this line               |
| `:Review next`     | Next comment                                |
| `:Review prev`     | Previous comment                            |
| `:Review summary`  | Summary                                     |
| `:Review clear`    | Clear every comment (asks first)            |
| `:Review clear!`   | Clear without asking                        |
| `:Review help`     | Help                                        |
| `:Review mode`     | Toggle review mode                          |
| `:Review reload`   | Reread saved comments                       |

`:'<,'>Review` comments on the visual range.

## Exported prompt

`:Review clip` and `<leader>ry` copy this to the `+` register. Paths are relative to the git root.

```
Notes:

1. `src/api/handler.ts:42` - fix the off-by-one error here
2. `src/utils/helpers.ts:100-110` - [suggestion] extract this block into a helper
3. `src/api/handler.ts` - file-level note
4. `review` - review-level note
```

`preamble` is the header. A multiline string is fine, including the intro from tuicr's `[export].intro`.

## Configuration

```lua
require("review-prompt").setup({
  keymaps = {
    add    = "<leader>rc", -- n + v
    manage = "<leader>rl", -- summary
    export = "<leader>ry", -- copy, does not clear
    mode   = "<leader>rr", -- toggle review mode
  },
  review_leader = ";", -- with review_maps.note, this is ;c
  review_maps = {
    comment = "c",
    file = "C",
    note = "c",
    delete = "dd",
    edit = "i",
    edit_end = "A",
    clip = "y",
    yank = "Y",
    next = "m",
    prev = "M",
    help = "?",
    visual_confirm = "<CR>",
  },
  comment_types = {}, -- or { "issue", "suggestion", "note" }
  -- stdpath("data")/review-prompt/<repo-slug>.json
  data_dir     = vim.fn.stdpath("data") .. "/review-prompt",
  highlight    = "DiagnosticWarn",
  input_prompt = "",
  preamble     = "Notes:",
})
```

Set a keymap or a review-mode key to `false` to drop it. `comment_types` entries can be strings or `{ id = "issue", definition = "must fix" }`.

## Persistence

Comments are saved on every change to `{data_dir}/<repo-slug>.json`. The slug is the sanitized basename of `git rev-parse --show-toplevel`. Outside a git repo, the file is `global.json`. The list is loaded on startup and again on `VimResume`. `:Review reload` rereads it.

Older saves (`path`, `ref`, `text` only) still load.

## Lua API

```lua
local rp = require("review-prompt")
rp.comment()
rp.file_comment()
rp.note()
rp.summary()
rp.clip()                  -- copy
rp.clip({ clear = true })  -- copy and clear
rp.delete_at_cursor()
rp.edit_at_cursor()        -- "end" puts the cursor at the end
rp.yank()
rp.next()
rp.prev()
rp.clear()
rp.clear({ force = true })
rp.reload()
rp.help()
rp.toggle_mode()
rp.status()                -- statusline text, empty when review mode is off

-- previous names
rp.add_comment()
rp.manage_comments()
rp.copy_and_clear()
```

## License

MIT
