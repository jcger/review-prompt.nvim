local model = require("review-prompt.model")
local persist = require("review-prompt.persist")

local M = {}

local S

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.is_open()
  return S ~= nil and S.win ~= nil and vim.api.nvim_win_is_valid(S.win)
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

function M.render()
  if not M.is_open() then return end
  local comments = S.get()
  local root = persist.repo_root()
  local list = model.sorted(comments)
  local lines = {}
  for _, c in ipairs(list) do
    table.insert(lines, model.summary_line(c, root))
  end
  if #lines == 0 then lines = { "No comments" } end
  local row = vim.api.nvim_win_get_cursor(S.win)[1]
  S.list = list
  set_lines(S.buf, lines)
  if #list == 0 then
    vim.api.nvim_win_set_cursor(S.win, { 1, 0 })
  else
    if row > #list then row = #list end
    if row < 1 then row = 1 end
    vim.api.nvim_win_set_cursor(S.win, { row, 0 })
  end
  local title = string.format(" Review comments (%d) ", #list)
  if S.win_opts.width >= 68 then
    title = string.format(" Review (%d)   Enter jump · dd delete · i edit · q close ", #list)
  end
  if vim.api.nvim_win_is_valid(S.win) then
    S.win_opts.title = title
    pcall(vim.api.nvim_win_set_config, S.win, S.win_opts)
  end
end

local function current()
  if not S or not S.list or #S.list == 0 then return nil end
  local row = vim.api.nvim_win_get_cursor(S.win)[1]
  return S.list[row]
end

function M.open(get_comments, actions)
  if #vim.api.nvim_list_uis() == 0 then
    local root = persist.repo_root()
    local lines = {}
    for _, c in ipairs(model.sorted(get_comments())) do
      table.insert(lines, model.summary_line(c, root))
    end
    if #lines == 0 then
      vim.notify("No comments collected", vim.log.levels.INFO)
    else
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end
    return
  end

  if M.is_open() then
    vim.api.nvim_set_current_win(S.win)
    S.get = get_comments
    S.actions = actions
    M.render()
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "reviewprompt-summary"

  local width = math.min(88, math.max(40, vim.o.columns - 4))
  local height = math.min(18, math.max(6, math.floor(vim.o.lines * 0.4)))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Review comments ",
    title_pos = "center",
    zindex = 50,
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  S = {
    buf = buf,
    win = win,
    win_opts = win_opts,
    get = get_comments,
    actions = actions,
    list = {},
  }
  M.render()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("q", M.close)
  map("<Esc>", M.close)
  map("<C-c>", M.close)
  map("<CR>", function()
    local c = current()
    if c and S.actions.jump then S.actions.jump(c) end
  end)
  map("dd", function()
    local c = current()
    if c and S.actions.delete then S.actions.delete(c) end
  end)
  map("i", function()
    local c = current()
    if c and S.actions.edit then S.actions.edit(c, "start") end
  end)
  map("A", function()
    local c = current()
    if c and S.actions.edit then S.actions.edit(c, "end") end
  end)
  map("y", function()
    local c = current()
    if c and S.actions.yank then S.actions.yank(c) end
  end)
  map("?", function()
    require("review-prompt.help").toggle()
  end)

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if S and S.win == win then M.close() end
    end,
  })
end

return M
