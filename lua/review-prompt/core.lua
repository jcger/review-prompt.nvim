local state   = require("review-prompt.state")
local persist = require("review-prompt.persist")
local marks   = require("review-prompt.marks")
local picker  = require("review-prompt.picker")

local M = {}

local function lnum_from_ref(ref)
  return tonumber(ref:match(":(%d+)"))
end

function M.add_comment(cfg)
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("review-prompt: no file", vim.log.levels.WARN)
    return
  end

  local mode = vim.fn.mode()
  local ref

  if mode == "v" or mode == "V" or mode == "\22" then
    local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
    local sl, el = s[2], e[2]
    if sl > el then sl, el = el, sl end
    ref = sl == el and string.format("%s:%d", path, sl)
                    or string.format("%s:%d-%d", path, sl, el)
  else
    ref = string.format("%s:%d", path, vim.api.nvim_win_get_cursor(0)[1])
  end

  local text = vim.fn.trim(vim.fn.input("Review comment: "))
  if text == "" then return end

  table.insert(state.comments, { path = path, ref = ref, text = text })
  marks.place(vim.api.nvim_get_current_buf(), path, lnum_from_ref(ref), text)
  persist.save(state.comments, cfg.data_dir)
  vim.notify(string.format("Comment added (%d total)", #state.comments))
end

function M.copy_and_clear(cfg)
  if #state.comments == 0 then
    vim.notify("No comments to copy", vim.log.levels.WARN)
    return
  end

  local lines = { "Please address the following code review comments:", "" }
  for _, c in ipairs(state.comments) do
    table.insert(lines, c.ref)
    table.insert(lines, "Comment: " .. c.text)
    table.insert(lines, "")
  end

  local count = #state.comments
  vim.fn.setreg("+", table.concat(lines, "\n"))
  marks.clear_all()
  state.comments = {}
  persist.save(state.comments, cfg.data_dir)
  vim.notify(string.format("%d comment%s copied and cleared", count, count == 1 and "" or "s"))
end

function M.manage_comments(cfg)
  if #state.comments == 0 then
    vim.notify("No comments collected", vim.log.levels.INFO)
    return
  end

  picker.open(
    state.comments,
    function(c, _)  -- on_jump
      local lnum = lnum_from_ref(c.ref)
      vim.cmd("edit " .. vim.fn.fnameescape(c.path))
      if lnum then vim.api.nvim_win_set_cursor(0, { lnum, 0 }) end
    end,
    function(c, idx)  -- on_delete
      local lnum = lnum_from_ref(c.ref)
      if lnum then marks.clear(c.path, lnum) end
      table.remove(state.comments, idx)
      persist.save(state.comments, cfg.data_dir)
      vim.notify("Comment removed")
    end,
    function(c, idx)  -- on_edit
      local new_text = vim.fn.trim(vim.fn.input("Edit comment: ", c.text))
      if new_text == "" then return end
      local lnum = lnum_from_ref(c.ref)
      if lnum then marks.clear(c.path, lnum) end
      state.comments[idx].text = new_text
      if lnum then marks.place(vim.fn.bufnr(c.path), c.path, lnum, new_text) end
      persist.save(state.comments, cfg.data_dir)
      vim.notify("Comment updated")
    end
  )
end

return M
