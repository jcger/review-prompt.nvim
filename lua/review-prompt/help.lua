local M = {}

local S

local function keymap_rows(cfg)
  local m = cfg.review_maps or {}
  local rows = {}
  local function add(key, desc)
    if key and key ~= false and key ~= "" then
      table.insert(rows, string.format("  %-16s %s", key, desc))
    end
  end
  add(m.comment, "Comment on this line, or the visual selection")
  add(m.file, "Comment on this file")
  if cfg.review_leader and cfg.review_leader ~= false and m.note and m.note ~= false then
    add(cfg.review_leader .. m.note, "Review-level note")
  end
  add(m.delete, "Delete the comment on this line")
  add(m.edit, "Edit the comment on this line")
  add(m.edit_end, "Edit it, cursor at the end")
  add(m.clip, "Copy the review")
  add(m.yank, "Copy the comment on this line")
  if m.next and m.next ~= false and m.prev and m.prev ~= false then
    add(m.next .. " / " .. m.prev, "Next / previous comment")
  else
    add(m.next, "Next comment")
    add(m.prev, "Previous comment")
  end
  add(m.visual_confirm, "Comment on the visual selection")
  add(m.help, "Toggle this help")
  return rows
end

function M.lines()
  local cfg = require("review-prompt.config").options
  local on = require("review-prompt.mode").is_on()
  local km = cfg.keymaps or {}
  local lines = {
    on and "Review mode is on" or "Review mode is off",
    "",
    "Review mode",
  }
  for _, row in ipairs(keymap_rows(cfg)) do
    table.insert(lines, row)
  end
  vim.list_extend(lines, {
    "",
    "Summary",
    "  j / k            Move",
    "  Enter            Jump to the comment",
    "  dd               Delete",
    "  i / A            Edit",
    "  y                Copy that comment",
    "  Esc / q          Close",
    "",
    "Commands",
    "  :Review              Summary",
    "  :Review comment      Comment on this line, or a range",
    "  :Review file         Comment on this file",
    "  :Review note         Review-level note",
    "  :Review delete       Delete the comment on this line",
    "  :Review edit         Edit the comment on this line",
    "  :Review clip         Copy the review",
    "  :Review clip!        Copy the review and clear it",
    "  :Review yank         Copy the comment on this line",
    "  :Review next         Next comment",
    "  :Review prev         Previous comment",
    "  :Review summary      Summary",
    "  :Review clear        Clear every comment",
    "  :Review clear!       Clear without asking",
    "  :Review help         Toggle this help",
    "  :Review mode         Toggle review mode",
    "  :Review reload       Reread saved comments",
    "",
    "Always on",
  })
  local function mapline(key, desc)
    if key and key ~= false then
      table.insert(lines, string.format("  %-18s %s", key, desc))
    end
  end
  mapline(km.add, "Comment")
  mapline(km.manage, "Summary")
  mapline(km.export, "Copy the review")
  mapline(km.mode, "Toggle review mode")
  vim.list_extend(lines, {
    "",
    "Comment box",
    "  Enter / Ctrl-s       Save",
    "  Ctrl-j / Shift-Enter New line",
    "  Tab / Shift-Tab      Cycle comment type",
    "  Esc                  Cancel",
    "",
    "Review mode overrides c, C, dd, i, A, y, Y, m, M, and ?.",
    "Toggle it off to use those keys as usual.",
    "File notes and review notes are edited from the summary.",
  })
  if cfg.review_leader == ";" then
    table.insert(lines, "")
    table.insert(lines, "; waits briefly while review mode is on, because ;c is the review note.")
  end
  local ntypes = #(cfg.comment_types or {})
  if ntypes == 0 then
    table.insert(lines, "")
    table.insert(lines, "Set comment_types to cycle a prefix with Tab in the comment box.")
  end
  return lines
end

function M.close()
  if not S or S.closing then return end
  S.closing = true
  local win, buf = S.win, S.buf
  S = nil
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

function M.open()
  local lines = M.lines()
  if #vim.api.nvim_list_uis() == 0 then
    vim.api.nvim_echo({ { table.concat(lines, "\n"), "Normal" } }, true, {})
    return
  end
  if S and S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_set_current_win(S.win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "reviewprompt-help"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.min(78, math.max(40, vim.o.columns - 4))
  local height = math.min(#lines, math.max(8, vim.o.lines - 6))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Review help ",
    title_pos = "center",
    zindex = 70,
  })
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  S = { buf = buf, win = win }

  local function map(lhs)
    vim.keymap.set("n", lhs, M.close, { buffer = buf, silent = true, nowait = true })
  end
  map("q")
  map("?")
  map("<Esc>")

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if S and S.win == win then M.close() end
    end,
  })
end

function M.toggle()
  if S and S.win and vim.api.nvim_win_is_valid(S.win) then
    M.close()
  else
    M.open()
  end
end

return M
