local M = {}

local function load_modules()
  return {
    config  = require("review-prompt.config"),
    state   = require("review-prompt.state"),
    persist = require("review-prompt.persist"),
    marks   = require("review-prompt.marks"),
    core    = require("review-prompt.core"),
  }
end

function M.setup(opts)
  vim.g.review_prompt_did_setup = true

  local m = load_modules()
  m.config.options = vim.tbl_deep_extend("force", m.config.defaults, opts or {})
  local cfg = m.config.options

  m.marks.setup(cfg.highlight)

  local aug = vim.api.nvim_create_augroup("ReviewPrompt", { clear = true })

  local function reload()
    local loaded = m.persist.load(cfg.data_dir)
    if loaded then
      m.marks.clear_all()
      m.state.comments = loaded
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        m.marks.replay_for_buf(bufnr, m.state.comments)
      end
    end
  end

  vim.api.nvim_create_autocmd("VimEnter",  { group = aug, once = true, callback = reload })
  vim.api.nvim_create_autocmd("VimResume", { group = aug, callback = reload })
  vim.api.nvim_create_autocmd("BufEnter",  {
    group = aug,
    callback = function(ev)
      m.marks.replay_for_buf(ev.buf, m.state.comments)
    end,
  })

  local function map(mode, key, fn, desc)
    if key and key ~= false then
      vim.keymap.set(mode, key, fn, { desc = desc })
    end
  end

  map({ "n", "v" }, cfg.keymaps.add,    function() m.core.add_comment(cfg) end,     "Review: Add comment")
  map("n",          cfg.keymaps.manage,  function() m.core.manage_comments(cfg) end, "Review: Manage comments")
  map("n",          cfg.keymaps.export,  function() m.core.copy_and_clear(cfg) end,  "Review: Copy as AI prompt")
end

M.add_comment     = function() require("review-prompt.core").add_comment(require("review-prompt.config").options) end
M.manage_comments = function() require("review-prompt.core").manage_comments(require("review-prompt.config").options) end
M.copy_and_clear  = function() require("review-prompt.core").copy_and_clear(require("review-prompt.config").options) end

return M
