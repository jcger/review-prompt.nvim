local M = {}

local function store_path(data_dir)
  local root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 or root == "" then
    return data_dir .. "/global.json"
  end
  local slug = vim.fn.fnamemodify(root, ":t"):gsub("[^%w%-_]", "-")
  return data_dir .. "/" .. slug .. ".json"
end

function M.save(comments, data_dir)
  vim.fn.mkdir(data_dir, "p")
  local path = store_path(data_dir)
  local f = io.open(path, "w")
  if f then
    f:write(vim.fn.json_encode(comments))
    f:close()
  end
end

function M.load(data_dir)
  local path = store_path(data_dir)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil end
  local ok, decoded = pcall(vim.fn.json_decode, content)
  if ok and type(decoded) == "table" then return decoded end
  return nil
end

return M
