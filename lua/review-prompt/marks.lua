local model = require("review-prompt.model")

local M = {}

local ns

local function abspath(path)
  if not path or path == "" then return "" end
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

local function same_path(a, b)
  if not a or not b or a == "" or b == "" then return false end
  return abspath(a) == abspath(b)
end

local function label(c)
  local bits = {}
  if c.kind == "range" and c.lnum and c.end_lnum then
    table.insert(bits, string.format("%d-%d", c.lnum, c.end_lnum))
  end
  if c.type and c.type ~= "" then
    table.insert(bits, "[" .. c.type .. "]")
  end
  table.insert(bits, model.one_line(c.text, 80))
  return table.concat(bits, " ")
end

function M.setup(highlight)
  ns = vim.api.nvim_create_namespace("review_prompt")
  vim.api.nvim_set_hl(0, "ReviewPrompt", { link = highlight or "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "ReviewPromptMode", { link = "IncSearch" })
end

function M.redraw_buf(bufnr, comments)
  if not ns or not vim.api.nvim_buf_is_valid(bufnr) then return end
  if vim.bo[bufnr].buftype ~= "" then return end
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then return end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count < 1 then return end

  local by_line = {}
  local file_notes = {}
  for _, c in ipairs(comments) do
    if same_path(c.path, path) then
      if c.kind == "file" then
        table.insert(file_notes, c)
      elseif c.lnum and c.lnum >= 1 and c.lnum <= line_count then
        by_line[c.lnum] = by_line[c.lnum] or {}
        table.insert(by_line[c.lnum], c)
      end
    end
  end

  if #file_notes > 0 then
    local virt = {}
    for _, c in ipairs(file_notes) do
      table.insert(virt, { { "← " .. label(c), "ReviewPrompt" } })
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, 0, 0, {
      virt_lines = virt,
      virt_lines_above = true,
    })
  end

  for lnum, list in pairs(by_line) do
    local parts = {}
    for i, c in ipairs(list) do
      if i > 1 then table.insert(parts, " · ") end
      table.insert(parts, label(c))
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, lnum - 1, 0, {
      virt_text = { { model.shorten("  ← " .. table.concat(parts), 120), "ReviewPrompt" } },
      virt_text_pos = "eol",
    })
  end
end

function M.redraw_all(comments)
  if not ns then return end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.redraw_buf(bufnr, comments)
    end
  end
end

return M
