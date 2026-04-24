local M = {}

local ns
local store = {}  -- path -> { lnum -> extmark_id }

function M.setup(highlight)
  ns = vim.api.nvim_create_namespace("review_prompt")
  vim.api.nvim_set_hl(0, "ReviewPrompt", { link = highlight })
end

function M.place(bufnr, path, lnum, text)
  if not ns or not bufnr or bufnr == -1 then return end
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, lnum - 1, 0, {
    virt_text = { { "  ← " .. text, "ReviewPrompt" } },
    virt_text_pos = "eol",
  })
  if not ok then return end
  store[path] = store[path] or {}
  store[path][lnum] = id
end

function M.clear(path, lnum)
  if not (store[path] and store[path][lnum]) then return end
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, store[path][lnum])
  end
  store[path][lnum] = nil
end

function M.clear_all()
  for path, _ in pairs(store) do
    local bufnr = vim.fn.bufnr(path)
    if bufnr ~= -1 then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
    end
  end
  store = {}
end

function M.replay_for_buf(bufnr, comments)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then return end
  for _, c in ipairs(comments) do
    if c.path == path then
      local lnum = tonumber(c.ref:match(":(%d+)"))
      if lnum and not (store[path] and store[path][lnum]) then
        M.place(bufnr, path, lnum, c.text)
      end
    end
  end
end

return M
