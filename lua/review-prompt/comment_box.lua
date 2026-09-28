local M = {}

local active

local function split_lines(text)
  if not text or text == "" then return { "" } end
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  if #lines == 0 then return { "" } end
  return lines
end

local function current_type(types, idx)
  if idx == 0 or not types[idx] then return nil end
  return types[idx].id
end

local function title_for(types, idx, width, base)
  local label = (base and base ~= "") and base or "Comment"
  if #label > 24 then label = label:sub(1, 24) end
  if idx > 0 and types[idx] then
    label = "[" .. types[idx].id .. "]"
  end
  local hint = " · Enter save · Esc cancel"
  if #types > 0 then hint = " · Tab type" .. hint end
  local full = label .. hint
  if width and #full > width - 2 then return label end
  return full
end

function M.open(opts)
  opts = opts or {}
  if active and active.win and vim.api.nvim_win_is_valid(active.win) then
    vim.api.nvim_set_current_win(active.win)
    return
  end

  local types = opts.types or {}
  if opts.type and opts.type ~= "" then
    local found = false
    for _, t in ipairs(types) do
      if t.id == opts.type then
        found = true
        break
      end
    end
    if not found then
      types = vim.list_extend({ { id = opts.type } }, types)
    end
  end
  local idx = 0
  if opts.type and opts.type ~= "" then
    for i, t in ipairs(types) do
      if t.id == opts.type then
        idx = i
        break
      end
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "reviewprompt-comment"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, split_lines(opts.text or ""))

  local width = math.min(78, math.max(24, vim.o.columns - 4))
  local height = math.min(12, math.max(4, vim.o.lines - 6))
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
    title = title_for(types, idx, width, opts.label),
    title_pos = "center",
    zindex = 60,
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("wrap", true, { win = win })

  active = { buf = buf, win = win, done = false }

  local function close_ui()
    local state = active
    active = nil
    if not state then return end
    if vim.fn.mode():match("^[iR]") then vim.cmd("stopinsert") end
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      pcall(vim.api.nvim_win_close, state.win, true)
    end
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end
  end

  local function save()
    if not active or active.done then return end
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    text = vim.fn.trim(text)
    if text == "" then
      vim.notify("Comment cannot be empty", vim.log.levels.WARN)
      return
    end
    active.done = true
    local typ = current_type(types, idx)
    local cb = opts.on_save
    close_ui()
    if cb then cb(text, typ) end
  end

  local function cancel()
    if not active or active.done then return end
    active.done = true
    close_ui()
  end

  local function newline()
    local row0, col0 = unpack(vim.api.nvim_win_get_cursor(win))
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local line = lines[row0] or ""
    local left = line:sub(1, col0)
    local right = line:sub(col0 + 1)
    lines[row0] = left
    table.insert(lines, row0 + 1, right)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(win, { row0 + 1, 0 })
  end

  local function set_idx(next_idx)
    if #types == 0 then return end
    if next_idx > #types then next_idx = 0 end
    if next_idx < 0 then next_idx = #types end
    idx = next_idx
    win_opts.title = title_for(types, idx, win_opts.width, opts.label)
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_config, win, win_opts)
    end
  end

  local map = function(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("i", "<CR>", save)
  map("n", "<CR>", save)
  map("i", "<C-s>", save)
  map("n", "<C-s>", save)
  map("i", "<C-j>", newline)
  map("i", "<S-CR>", newline)
  map("i", "<C-CR>", newline)
  map("i", "<Esc>", cancel)
  map("i", "<C-c>", cancel)
  map("n", "<Esc>", cancel)
  map("n", "q", cancel)
  map("n", "i", function() vim.cmd("startinsert") end)
  map("n", "a", function() vim.cmd("startinsert") end)
  if #types > 0 then
    map("i", "<Tab>", function() set_idx(idx + 1) end)
    map("n", "<Tab>", function() set_idx(idx + 1) end)
    map("i", "<S-Tab>", function() set_idx(idx - 1) end)
    map("n", "<S-Tab>", function() set_idx(idx - 1) end)
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if active and not active.done then cancel() end
    end,
  })

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local last = math.max(1, #lines)
  if opts.cursor == "end" then
    vim.api.nvim_win_set_cursor(win, { last, #lines[last] })
  else
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end
  vim.cmd("startinsert")
end

return M
