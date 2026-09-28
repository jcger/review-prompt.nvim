local model = require("review-prompt.model")
local persist = require("review-prompt.persist")
local marks = require("review-prompt.marks")
local state = require("review-prompt.state")
local summary = require("review-prompt.summary")
local comment_box = require("review-prompt.comment_box")

local M = {}

local pin = { comment = nil, path = nil, lnum = nil }

local function cfg()
  return require("review-prompt.config").options
end

local function abspath(path)
  if not path or path == "" then return path end
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

local function hydrate(raw)
  local list = model.normalize_list(raw)
  for _, c in ipairs(list) do
    if c.path then c.path = abspath(c.path) end
  end
  return list
end

local function changed()
  persist.save(model.serialize_list(state.comments), cfg().data_dir)
  marks.redraw_all(state.comments)
  if summary.is_open() then summary.render() end
end

local function count_word(n)
  return n == 1 and "comment" or "comments"
end

function M.on_cursor_moved()
  local ok, pos = pcall(vim.api.nvim_win_get_cursor, 0)
  if not ok then return end
  local path = vim.api.nvim_buf_get_name(0)
  if path ~= "" then path = abspath(path) end
  if pin.path ~= path or pin.lnum ~= pos[1] then
    pin.comment, pin.path, pin.lnum = nil, nil, nil
  end
end

function M.load(opts)
  opts = opts or {}
  local loaded, err = persist.load(cfg().data_dir)
  if err == "corrupt" then
    vim.notify("review-prompt: could not read saved comments", vim.log.levels.WARN)
    return
  end
  if err == "missing" then
    state.comments = {}
  else
    state.comments = hydrate(loaded)
  end
  marks.redraw_all(state.comments)
  if summary.is_open() then summary.render() end
  if not opts.quiet then
    vim.notify(string.format("Review reloaded (%d)", #state.comments))
  end
end

function M.save_new(spec)
  local item = model.normalize({
    kind = spec.kind,
    path = spec.path and abspath(spec.path) or nil,
    lnum = spec.lnum,
    end_lnum = spec.end_lnum,
    text = vim.fn.trim(spec.text or ""),
    type = spec.type,
  })
  if not item then return end
  table.insert(state.comments, item)
  changed()
  vim.notify(string.format("Comment added (%d total)", #state.comments))
end

local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    vim.notify("review-prompt: no file", vim.log.levels.WARN)
    return nil
  end
  return abspath(name)
end

local function leave_visual()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local s, e = vim.fn.line("v"), vim.fn.line(".")
    if s > e then s, e = e, s end
    pcall(vim.cmd, "normal! \27")
    return s, e
  end
  return nil
end

function M.target_from_view()
  local path = current_file()
  if not path then return nil end
  local s, e = leave_visual()
  if not s then
    s = vim.api.nvim_win_get_cursor(0)[1]
    e = s
  end
  if s == e then
    return { kind = "line", path = path, lnum = s }
  end
  return { kind = "range", path = path, lnum = s, end_lnum = e }
end

local function open_box(existing, spec)
  spec = spec or {}
  local options = cfg()
  local types = model.normalize_types(options.comment_types)
  vim.schedule(function()
    local function on_save(text, typ)
      if existing then
        existing.text = text
        existing.type = (typ and typ ~= "") and typ or nil
        changed()
        vim.notify("Comment updated")
      else
        M.save_new({
          kind = spec.kind,
          path = spec.path,
          lnum = spec.lnum,
          end_lnum = spec.end_lnum,
          text = text,
          type = typ,
        })
      end
    end
    if #vim.api.nvim_list_uis() == 0 then
      local prompt = options.input_prompt ~= "" and options.input_prompt or "Comment: "
      local text = vim.fn.trim(vim.fn.input(prompt, existing and existing.text or ""))
      if text == "" then return end
      on_save(text, existing and existing.type or nil)
      return
    end
    comment_box.open({
      text = existing and existing.text or "",
      types = types,
      type = existing and existing.type or nil,
      cursor = spec.cursor or "start",
      label = options.input_prompt,
      on_save = on_save,
    })
  end)
end

function M.comment()
  local spec = M.target_from_view()
  if not spec then return end
  open_box(nil, spec)
end

function M.comment_lines(line1, line2)
  local path = current_file()
  if not path then return end
  if line1 > line2 then line1, line2 = line2, line1 end
  if line1 == line2 then
    open_box(nil, { kind = "line", path = path, lnum = line1 })
  else
    open_box(nil, { kind = "range", path = path, lnum = line1, end_lnum = line2 })
  end
end

function M.file()
  local path = current_file()
  if not path then return end
  open_box(nil, { kind = "file", path = path })
end

function M.note()
  open_box(nil, { kind = "review" })
end

function M.comments_at_cursor()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then return {} end
  local path = abspath(name)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local hits = {}
  for _, c in ipairs(state.comments) do
    if c.path and abspath(c.path) == path and c.lnum then
      local last = c.end_lnum or c.lnum
      if lnum >= c.lnum and lnum <= last then
        table.insert(hits, c)
      end
    end
  end
  return hits
end

local function pick_at_cursor(action)
  local hits = M.comments_at_cursor()
  if #hits == 0 then
    vim.notify("No comment at cursor", vim.log.levels.WARN)
    return
  end
  if #hits == 1 then
    action(hits[1])
    return
  end
  vim.ui.select(hits, {
    prompt = "Comment at cursor",
    format_item = function(c)
      return model.type_prefix(c) .. model.one_line(c.text, 80)
    end,
  }, function(choice)
    if choice then action(choice) end
  end)
end

function M.edit(comment, where)
  if not comment then
    pick_at_cursor(function(c) M.edit(c, where) end)
    return
  end
  open_box(comment, { cursor = where == "end" and "end" or "start" })
end

function M.delete_at_cursor()
  pick_at_cursor(function(c) M.remove(c) end)
end

function M.remove(comment)
  for i, c in ipairs(state.comments) do
    if c == comment then
      table.remove(state.comments, i)
      break
    end
  end
  if pin.comment == comment then
    pin.comment, pin.path, pin.lnum = nil, nil, nil
  end
  changed()
  vim.notify("Comment removed")
end

function M.yank_comment(comment)
  vim.fn.setreg("+", comment.text)
  vim.notify("Comment copied")
end

function M.yank_at_cursor()
  pick_at_cursor(M.yank_comment)
end

local function show_path(path)
  local target = abspath(path)
  if target and abspath(vim.api.nvim_buf_get_name(0)) == target then
    return true
  end
  -- Allow leaving a modified buffer without discarding it.
  local prev_hidden = vim.o.hidden
  vim.o.hidden = true
  local function restore()
    vim.o.hidden = prev_hidden
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and abspath(vim.api.nvim_buf_get_name(bufnr)) == target then
      local ok = pcall(vim.api.nvim_set_current_buf, bufnr)
      restore()
      return ok
    end
  end
  local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
  restore()
  return ok
end

function M.jump(c)
  if c.kind == "review" or not c.path or c.path == "" then
    local path = vim.api.nvim_buf_get_name(0)
    if path ~= "" then path = abspath(path) end
    pin.comment = c
    pin.path = path
    local pos = vim.api.nvim_win_get_cursor(0)
    pin.lnum = pos[1]
    vim.notify(c.text, vim.log.levels.INFO)
    return
  end
  if not show_path(c.path) then
    vim.notify("Cannot open " .. c.path, vim.log.levels.WARN)
    return
  end
  local lnum = (c.kind == "file") and 1 or (c.lnum or 1)
  local max = vim.api.nvim_buf_line_count(0)
  if lnum < 1 then lnum = 1 end
  if lnum > max then lnum = max end
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  pcall(vim.cmd, "normal! zz")
  pin.comment = c
  pin.path = abspath(vim.api.nvim_buf_get_name(0))
  pin.lnum = lnum
end

function M.step(dir)
  local path = vim.api.nvim_buf_get_name(0)
  if path ~= "" then path = abspath(path) end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local dest, err = model.neighbor(state.comments, path, lnum, pin.comment, dir)
  if not dest then
    if err == "empty" then
      vim.notify("No comments collected", vim.log.levels.INFO)
    else
      vim.notify("No other comments", vim.log.levels.INFO)
    end
    return
  end
  M.jump(dest)
end

function M.clip(and_clear)
  if #state.comments == 0 then
    vim.notify("No comments to copy", vim.log.levels.WARN)
    return
  end
  local text = model.export_text(state.comments, cfg().preamble, persist.repo_root())
  vim.fn.setreg("+", text)
  local n = #state.comments
  if and_clear then
    state.comments = {}
    pin.comment, pin.path, pin.lnum = nil, nil, nil
    changed()
    vim.notify(string.format("%d %s copied and cleared", n, count_word(n)))
  else
    vim.notify(string.format("%d %s copied", n, count_word(n)))
  end
end

function M.clear(force)
  if #state.comments == 0 then
    vim.notify("No comments to clear", vim.log.levels.INFO)
    return
  end
  if not force then
    local choice = vim.fn.confirm("Clear all review comments?", "&Yes\n&No", 2)
    if choice ~= 1 then return end
  end
  state.comments = {}
  pin.comment, pin.path, pin.lnum = nil, nil, nil
  changed()
  vim.notify("Comments cleared")
end

function M.summary()
  summary.open(function() return state.comments end, {
    jump = function(c)
      summary.close()
      M.jump(c)
    end,
    delete = function(c) M.remove(c) end,
    edit = function(c, where) M.edit(c, where) end,
    yank = function(c) M.yank_comment(c) end,
  })
end

function M.command(opts)
  local parts = {}
  for word in (opts.args or ""):gmatch("%S+") do
    table.insert(parts, word)
  end
  local verb = parts[1]
  local force = opts.bang
  if not verb or verb == "" then
    verb = (opts.range == 2) and "comment" or "summary"
  end
  if verb:sub(-1) == "!" then
    force = true
    verb = verb:sub(1, -2)
  end
  verb = verb:lower()
  if verb == "export" or verb == "copy" then verb = "clip" end
  if verb == "previous" then verb = "prev" end

  if verb == "comment" then
    if opts.range == 2 then
      M.comment_lines(opts.line1, opts.line2)
    else
      M.comment()
    end
  elseif verb == "file" then
    M.file()
  elseif verb == "note" then
    M.note()
  elseif verb == "delete" then
    M.delete_at_cursor()
  elseif verb == "edit" then
    M.edit(nil, "start")
  elseif verb == "clip" then
    M.clip(force)
  elseif verb == "yank" then
    M.yank_at_cursor()
  elseif verb == "next" then
    M.step(1)
  elseif verb == "prev" then
    M.step(-1)
  elseif verb == "summary" then
    M.summary()
  elseif verb == "clear" then
    M.clear(force)
  elseif verb == "help" then
    require("review-prompt.help").toggle()
  elseif verb == "mode" then
    require("review-prompt.mode").toggle()
  elseif verb == "reload" then
    M.load()
  else
    vim.notify("Unknown review command: " .. verb, vim.log.levels.WARN)
  end
end

return M
