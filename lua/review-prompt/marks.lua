local state = require("review-prompt.state")

local M = {}

local MAX_BODY = 12
local BODY_WIDTH = 64

local ns

local function abspath(path)
  if not path or path == "" then return "" end
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

local function same_path(a, b)
  if not a or not b or a == "" or b == "" then return false end
  return abspath(a) == abspath(b)
end

local function disp(text)
  return vim.fn.strdisplaywidth(text or "")
end

local function wrap_line(text, width)
  if text == "" then return { "" } end
  local out, line, used = {}, "", 0
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local w = disp(char)
    if used > 0 and used + w > width then
      table.insert(out, line)
      line, used = char, w
    else
      line = line .. char
      used = used + w
    end
  end
  if line ~= "" then table.insert(out, line) end
  if #out == 0 then return { "" } end
  return out
end

local function box_virt(c, corner)
  local where = ""
  if c.kind == "range" and c.lnum and c.end_lnum and c.end_lnum ~= c.lnum then
    where = string.format(" L%d-%d", c.lnum, c.end_lnum)
  elseif c.lnum then
    where = string.format(" L%d", c.lnum)
  elseif c.kind == "file" then
    where = " file"
  end
  local tag = (c.type and c.type ~= "") and ("[" .. c.type .. "]") or ""
  local bits = { " " .. corner .. "─" }
  if tag ~= "" then table.insert(bits, tag) end
  if where ~= "" then table.insert(bits, vim.trim(where)) end
  local head = table.concat(bits, " ")

  local body = {}
  for _, raw in ipairs(vim.split(c.text or "", "\n", { plain = true })) do
    for _, piece in ipairs(wrap_line(raw, BODY_WIDTH)) do
      table.insert(body, piece)
      if #body >= MAX_BODY then break end
    end
    if #body >= MAX_BODY then break end
  end
  if #body == 0 then body = { "" } end

  local width = disp(head)
  for _, line in ipairs(body) do
    width = math.max(width, 4 + disp(line))
  end
  width = math.max(width, 18)

  local virt = {
    { { head .. string.rep("─", math.max(0, width - disp(head))), "ReviewPromptBorder" } },
  }
  for _, line in ipairs(body) do
    table.insert(virt, {
      { " │ ", "ReviewPromptBorder" },
      { line, "ReviewPromptBody" },
    })
  end
  table.insert(virt, {
    { " ╰" .. string.rep("─", math.max(2, width - 2)), "ReviewPromptBorder" },
  })
  return virt
end

local function extend(dst, src)
  for _, line in ipairs(src) do
    table.insert(dst, line)
  end
end

function M.setup(highlight)
  ns = vim.api.nvim_create_namespace("review_prompt")
  vim.api.nvim_set_hl(0, "ReviewPrompt", { link = highlight or "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "ReviewPromptBorder", { link = highlight or "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "ReviewPromptBody", { link = "Normal" })
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
    if c ~= state.editing and same_path(c.path, path) then
      if c.kind == "file" then
        table.insert(file_notes, c)
      elseif c.lnum and c.lnum >= 1 and c.lnum <= line_count then
        local anchor = c.end_lnum or c.lnum
        if anchor < 1 then anchor = 1 end
        if anchor > line_count then anchor = line_count end
        by_line[anchor] = by_line[anchor] or {}
        table.insert(by_line[anchor], c)
      end
    end
  end

  if #file_notes > 0 then
    local virt = {}
    for _, c in ipairs(file_notes) do
      extend(virt, box_virt(c, "╭"))
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, 0, 0, {
      virt_lines = virt,
      virt_lines_above = true,
    })
  end

  for lnum, list in pairs(by_line) do
    local virt = {}
    for _, c in ipairs(list) do
      extend(virt, box_virt(c, "├"))
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, lnum - 1, 0, {
      virt_lines = virt,
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
