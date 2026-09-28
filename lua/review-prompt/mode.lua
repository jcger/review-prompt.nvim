local M = {}

local active = false
local attached = {}

local SKIP_FT = {
  netrw = true,
  help = true,
  qf = true,
  oil = true,
  NvimTree = true,
  ["neo-tree"] = true,
  fugitive = true,
  TelescopePrompt = true,
  lazy = true,
  mason = true,
  notify = true,
}

local function should_map(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end
  local bo = vim.bo[buf]
  if bo.buftype ~= "" then return false end
  local ft = bo.filetype or ""
  if ft:find("^reviewprompt") then return false end
  if SKIP_FT[ft] then return false end
  return true
end

local function unbind(buf)
  local specs = attached[buf]
  if not specs then return end
  if vim.api.nvim_buf_is_valid(buf) then
    for _, spec in ipairs(specs) do
      pcall(vim.keymap.del, spec[1], spec[2], { buffer = buf })
    end
  end
  attached[buf] = nil
end

local function bind(buf)
  if attached[buf] or not should_map(buf) then return end
  local cfg = require("review-prompt.config").options
  local maps = cfg.review_maps or {}
  local specs = {}
  local function set(mode, lhs, fn, desc)
    if not lhs or lhs == false or lhs == "" then return end
    vim.keymap.set(mode, lhs, fn, {
      buffer = buf,
      silent = true,
      nowait = true,
      desc = desc,
    })
    table.insert(specs, { mode, lhs })
  end
  local function core()
    return require("review-prompt.core")
  end

  set("n", maps.comment, function() core().comment() end, "Review: Comment")
  set("x", maps.comment, function() core().comment() end, "Review: Comment")
  set("x", maps.visual_confirm, function() core().comment() end, "Review: Comment")
  set("n", maps.file, function() core().file() end, "Review: File comment")
  set("n", maps.delete, function() core().delete_at_cursor() end, "Review: Delete comment")
  set("n", maps.edit, function() core().edit(nil, "start") end, "Review: Edit comment")
  set("n", maps.edit_end, function() core().edit(nil, "end") end, "Review: Edit comment at end")
  set("n", maps.clip, function() core().clip(false) end, "Review: Copy review")
  set("n", maps.yank, function() core().yank_at_cursor() end, "Review: Copy comment")
  set("n", maps.next, function() core().step(1) end, "Review: Next comment")
  set("n", maps.prev, function() core().step(-1) end, "Review: Previous comment")
  set("n", maps.help, function() require("review-prompt.help").toggle() end, "Review: Help")

  local leader = cfg.review_leader
  if leader and leader ~= false and maps.note and maps.note ~= false then
    set("n", leader .. maps.note, function() core().note() end, "Review: Review note")
  end
  attached[buf] = specs
end

local function signal()
  pcall(vim.cmd, "redrawstatus")
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "ReviewPromptMode" })
end

function M.is_on()
  return active
end

function M.disable(opts)
  opts = opts or {}
  if not active then return end
  active = false
  vim.g.review_prompt_mode = nil
  pcall(vim.api.nvim_del_augroup_by_name, "ReviewPromptKeys")
  local bufs = {}
  for buf in pairs(attached) do
    table.insert(bufs, buf)
  end
  for _, buf in ipairs(bufs) do
    unbind(buf)
  end
  signal()
  if not opts.quiet then vim.notify("Review mode off") end
end

function M.enable(opts)
  opts = opts or {}
  if active then M.disable({ quiet = true }) end
  active = true
  vim.g.review_prompt_mode = 1
  local aug = vim.api.nvim_create_augroup("ReviewPromptKeys", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = aug,
    callback = function(ev) bind(ev.buf) end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = aug,
    callback = function(ev) attached[ev.buf] = nil end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then bind(buf) end
  end
  signal()
  if not opts.quiet then vim.notify("Review mode on") end
end

function M.toggle()
  if active then M.disable() else M.enable() end
end

return M
