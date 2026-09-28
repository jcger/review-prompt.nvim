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

local function chrome(types, idx, opts)
  local action = opts.action or "Add"
  local title = { { " " .. action .. " ", "FloatTitle" } }
  if idx > 0 and types[idx] then
    table.insert(title, { "[" .. types[idx].id .. "] ", "ReviewPrompt" })
  end
  if opts.line_label and opts.line_label ~= "" then
    table.insert(title, { opts.line_label .. " ", "Comment" })
  end
  local hint = "Enter save · Esc move · q cancel"
  if #types > 0 then hint = "Tab type · " .. hint end
  local border = opts.attached and { "├", "─", "╮", "│", "╯", "─", "╰", "│" } or "rounded"
  return title, " " .. hint .. " ", border
end

local function geometry(anchor_win, screen_row, height, border, title, footer)
  local ok = anchor_win and vim.api.nvim_win_is_valid(anchor_win)
  if not ok then
    local width = math.min(72, math.max(28, vim.o.columns - 4))
    local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))
    return {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = border,
      title = title,
      title_pos = "left",
      footer = footer,
      footer_pos = "right",
      zindex = 60,
    }
  end

  local info = vim.fn.getwininfo(anchor_win)[1] or {}
  local textoff = info.textoff or 0
  local win_w = vim.api.nvim_win_get_width(anchor_win)
  local win_h = vim.api.nvim_win_get_height(anchor_win)
  local width = math.min(80, math.max(28, win_w - textoff - 1))
  local row = screen_row or 1
  local chrome_h = 2
  if row + height + chrome_h > win_h then
    row = math.max(0, (screen_row or 1) - 1 - height - chrome_h)
  end
  return {
    relative = "win",
    win = anchor_win,
    row = row,
    col = textoff,
    width = width,
    height = height,
    style = "minimal",
    border = border,
    title = title,
    title_pos = "left",
    footer = footer,
    footer_pos = "right",
    zindex = 60,
  }
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
  local body = split_lines(opts.text or "")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, body)

  local function body_height()
    local n = #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return math.min(8, math.max(1, n))
  end

  local title, footer, border = chrome(types, idx, opts)
  local win_opts = geometry(opts.anchor_win, opts.screen_row, body_height(), border, title, footer)
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "NormalFloat:Normal,FloatBorder:ReviewPromptBorder,FloatTitle:Normal,FloatFooter:Comment",
    { win = win }
  )

  active = { buf = buf, win = win, done = false }

  local function apply_chrome()
    title, footer, border = chrome(types, idx, opts)
    win_opts = geometry(opts.anchor_win, opts.screen_row, body_height(), border, title, footer)
    win_opts.style = nil
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_config, win, win_opts)
    end
  end

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

  local function finish(saved)
    if saved and opts.on_save then opts.on_save(saved.text, saved.typ) end
    if opts.on_close then opts.on_close() end
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
    close_ui()
    finish({ text = text, typ = typ })
  end

  local function cancel()
    if not active or active.done then return end
    active.done = true
    close_ui()
    finish()
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
    apply_chrome()
  end

  local function set_idx(next_idx)
    if #types == 0 then return end
    if next_idx > #types then next_idx = 0 end
    if next_idx < 0 then next_idx = #types end
    idx = next_idx
    apply_chrome()
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
  map("i", "<Esc>", function() vim.cmd("stopinsert") end)
  map("i", "<C-c>", function() vim.cmd("stopinsert") end)
  map("n", "q", cancel)
  if #types > 0 then
    map("i", "<Tab>", function() set_idx(idx + 1) end)
    map("n", "<Tab>", function() set_idx(idx + 1) end)
    map("i", "<S-Tab>", function() set_idx(idx - 1) end)
    map("n", "<S-Tab>", function() set_idx(idx - 1) end)
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      if active and not active.done then apply_chrome() end
    end,
  })

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
    vim.api.nvim_win_set_cursor(win, { last, math.max(0, #lines[last]) })
    vim.cmd("startinsert!")
  else
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    vim.cmd("startinsert")
  end
end

return M
