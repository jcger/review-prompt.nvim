local M = {}

local function cfg()
  return require("review-prompt.config").options
end

function M.setup(opts)
  vim.g.review_prompt_did_setup = true

  local config = require("review-prompt.config")
  local state = require("review-prompt.state")
  local marks = require("review-prompt.marks")
  local core = require("review-prompt.core")
  local commands = require("review-prompt.commands")
  local mode = require("review-prompt.mode")

  config.options = vim.tbl_deep_extend("force", config.defaults, opts or {})
  local options = config.options

  marks.setup(options.highlight)

  local aug = vim.api.nvim_create_augroup("ReviewPrompt", { clear = true })

  local function load()
    core.load({ quiet = true })
  end

  if vim.v.vim_did_enter == 1 then
    load()
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      group = aug,
      once = true,
      callback = load,
    })
  end
  vim.api.nvim_create_autocmd("VimResume", { group = aug, callback = load })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = aug,
    callback = function(ev)
      marks.redraw_buf(ev.buf, state.comments)
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = aug,
    callback = function()
      core.on_cursor_moved()
    end,
  })

  local function map(mapmode, key, fn, desc)
    if key and key ~= false then
      vim.keymap.set(mapmode, key, fn, { desc = desc, silent = true })
    end
  end

  local keys = type(options.keymaps) == "table" and options.keymaps or {}
  map({ "n", "x" }, keys.add, function() core.comment() end, "Review: Add comment")
  map("n", keys.edit, function() core.edit(nil, "start") end, "Review: Edit comment")
  map("n", keys.delete, function() core.delete_at_cursor() end, "Review: Delete comment")
  map("n", keys.manage, function() core.summary() end, "Review: Summary")
  map("n", keys.export, function() core.clip(false) end, "Review: Copy review")
  map("n", keys.mode, function() mode.toggle() end, "Review: Toggle review mode")

  commands.register()

  if vim.g.review_prompt_mode == 1 then
    mode.enable({ quiet = true })
  end
end

function M.status()
  if vim.g.review_prompt_mode == 1 then
    return "%#ReviewPromptMode# REVIEW %*"
  end
  return ""
end

local function core()
  return require("review-prompt.core")
end

function M.comment() core().comment() end
function M.file_comment() core().file() end
function M.note() core().note() end
function M.delete_at_cursor() core().delete_at_cursor() end
function M.edit_at_cursor(where) core().edit(nil, where) end
function M.summary() core().summary() end
function M.clip(opts) core().clip(opts and opts.clear) end
function M.yank() core().yank_at_cursor() end
function M.next() core().step(1) end
function M.prev() core().step(-1) end
function M.clear(opts) core().clear(opts and opts.force) end
function M.reload() core().load() end
function M.help() require("review-prompt.help").toggle() end
function M.toggle_mode() require("review-prompt.mode").toggle() end

function M.add_comment() M.comment() end
function M.manage_comments() M.summary() end
function M.copy_and_clear() core().clip(true) end

return M
