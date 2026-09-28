local M = {}

local function split_utf8(s, i)
  local b = s:byte(i)
  if not b then return 1 end
  if b >= 0xF0 then return 4 end
  if b >= 0xE0 then return 3 end
  if b >= 0xC0 then return 2 end
  return 1
end

function M.shorten(text, max)
  text = text or ""
  max = max or 80
  local i, count = 1, 0
  while i <= #text and count < max do
    i = i + split_utf8(text, i)
    count = count + 1
  end
  if i > #text then return text end
  local cut = 1
  local n = 0
  local limit = math.max(1, max - 1)
  while cut <= #text and n < limit do
    cut = cut + split_utf8(text, cut)
    n = n + 1
  end
  return text:sub(1, cut - 1) .. "…"
end

function M.one_line(text, max)
  return M.shorten((text or ""):gsub("%s+", " "), max or 80)
end

function M.normalize_types(list)
  local out = {}
  if type(list) ~= "table" then return out end
  for _, t in ipairs(list) do
    if type(t) == "string" and t ~= "" then
      table.insert(out, { id = t })
    elseif type(t) == "table" and type(t.id) == "string" and t.id ~= "" then
      table.insert(out, { id = t.id, definition = t.definition })
    end
  end
  return out
end

function M.normalize(c)
  if type(c) ~= "table" or type(c.text) ~= "string" or c.text == "" then
    return nil
  end
  local kind = c.kind
  local lnum = tonumber(c.lnum)
  local end_lnum = tonumber(c.end_lnum)
  local path = (type(c.path) == "string" and c.path ~= "") and c.path or nil
  local typ = (type(c.type) == "string" and c.type ~= "") and c.type or nil

  if not kind then
    local ref = type(c.ref) == "string" and c.ref or ""
    local a, b = ref:match(":(%d+)%-(%d+)$")
    if a then
      kind, lnum, end_lnum = "range", tonumber(a), tonumber(b)
    else
      a = ref:match(":(%d+)$")
      if a then
        kind, lnum = "line", tonumber(a)
      elseif path then
        kind = "file"
      else
        kind = "review"
      end
    end
  end

  if kind == "range" and lnum and end_lnum and end_lnum < lnum then
    lnum, end_lnum = end_lnum, lnum
  end
  if kind == "range" and lnum and (not end_lnum or end_lnum == lnum) then
    kind, end_lnum = "line", nil
  end
  if kind ~= "line" and kind ~= "range" and kind ~= "file" and kind ~= "review" then
    return nil
  end
  if (kind == "line" or kind == "range") and (not path or not lnum) then
    return nil
  end
  if kind == "file" and not path then
    return nil
  end
  if kind == "review" then
    path, lnum, end_lnum = nil, nil, nil
  end
  if kind == "file" then
    lnum, end_lnum = nil, nil
  end
  if kind == "line" then
    end_lnum = nil
  end

  return {
    path = path,
    kind = kind,
    lnum = lnum,
    end_lnum = end_lnum,
    text = c.text,
    type = typ,
  }
end

function M.normalize_list(raw)
  local out = {}
  if type(raw) ~= "table" then return out end
  for _, c in ipairs(raw) do
    local n = M.normalize(c)
    if n then table.insert(out, n) end
  end
  return out
end

function M.serialize(c)
  local o = { kind = c.kind, text = c.text }
  if c.path and c.path ~= "" then o.path = c.path end
  if c.lnum then o.lnum = c.lnum end
  if c.end_lnum then o.end_lnum = c.end_lnum end
  if c.type and c.type ~= "" then o.type = c.type end
  return o
end

function M.serialize_list(comments)
  local out = {}
  for _, c in ipairs(comments) do
    table.insert(out, M.serialize(c))
  end
  return out
end

-- Sort key: reviews last; within a file, file notes then lines.
function M.coords(c)
  if c.kind == "review" or not c.path or c.path == "" then
    return 1, "", 0, 0
  end
  if c.kind == "file" then
    return 0, c.path, 0, 0
  end
  return 0, c.path, 1, c.lnum or 0
end

function M.sorted(comments)
  local indexed = {}
  for i, c in ipairs(comments) do
    indexed[i] = { c = c, i = i }
  end
  table.sort(indexed, function(a, b)
    local ag, ap, ab, al = M.coords(a.c)
    local bg, bp, bb, bl = M.coords(b.c)
    if ag ~= bg then return ag < bg end
    if ap ~= bp then return ap < bp end
    if ab ~= bb then return ab < bb end
    if al ~= bl then return al < bl end
    return a.i < b.i
  end)
  local out = {}
  for _, item in ipairs(indexed) do
    table.insert(out, item.c)
  end
  return out
end

-- -1 before the cursor, 0 on it, 1 after it.
function M.cmp_cursor(c, path, lnum)
  path = path or ""
  lnum = lnum or 1
  local cg, cp, cb, cl = M.coords(c)
  if cg ~= 0 then return 1 end
  if cp ~= path then return cp < path and -1 or 1 end
  if cb ~= 1 then return -1 end
  local last = c.end_lnum or cl
  if lnum >= cl and lnum <= last then return 0 end
  return cl < lnum and -1 or 1
end

function M.neighbor(comments, path, lnum, pin, dir)
  local list = M.sorted(comments)
  local n = #list
  if n == 0 then return nil, "empty" end

  local idx
  if pin ~= nil then
    for i, c in ipairs(list) do
      if c == pin then
        idx = i
        break
      end
    end
  end
  if idx == nil then
    idx = 0
    for i, c in ipairs(list) do
      if M.cmp_cursor(c, path, lnum) <= 0 then idx = i end
    end
  end

  if n == 1 then
    local only = list[1]
    if pin == only then return nil, "only" end
    if only.path and only.path == path then
      if only.kind == "file" and lnum == 1 then return nil, "only" end
      if only.lnum and lnum >= only.lnum and lnum <= (only.end_lnum or only.lnum) then
        return nil, "only"
      end
    end
  end

  local nxt = idx + dir
  if nxt < 1 then
    nxt = n
  elseif nxt > n then
    nxt = 1
  end
  return list[nxt]
end

function M.relative(path, root)
  if not path or path == "" then return "review" end
  if not root or root == "" then return path end
  local function norm(p)
    return p:gsub("\\", "/"):gsub("/+$", "")
  end
  local p, r = norm(path), norm(root)
  if p:sub(1, #r) == r then
    local sep = p:sub(#r + 1, #r + 1)
    if sep == "/" then
      local rest = p:sub(#r + 2)
      if rest ~= "" then return rest end
    end
  end
  return path
end

function M.type_prefix(c)
  if c.type and c.type ~= "" then return "[" .. c.type .. "] " end
  return ""
end

function M.anchor(c, root)
  if c.kind == "review" or not c.path or c.path == "" then
    return "review"
  end
  local label = M.relative(c.path, root)
  if c.kind == "range" and c.lnum and c.end_lnum and c.end_lnum ~= c.lnum then
    return string.format("%s:%d-%d", label, c.lnum, c.end_lnum)
  end
  if c.lnum and (c.kind == "line" or c.kind == "range") then
    return string.format("%s:%d", label, c.lnum)
  end
  return label
end

function M.summary_line(c, root)
  return string.format("%s  %s%s", M.anchor(c, root), M.type_prefix(c), M.one_line(c.text, 200))
end

function M.export_text(comments, preamble, root)
  local list = M.sorted(comments)
  local lines = {}
  if preamble and preamble ~= "" then
    table.insert(lines, preamble)
    table.insert(lines, "")
  end
  for i, c in ipairs(list) do
    local body = c.text:gsub("\r\n", "\n"):gsub("\n", "\n   ")
    local anchor = M.anchor(c, root):gsub("`", "'")
    table.insert(lines, string.format("%d. `%s` - %s%s", i, anchor, M.type_prefix(c), body))
  end
  if #lines == 0 then return "" end
  return table.concat(lines, "\n") .. "\n"
end

return M
