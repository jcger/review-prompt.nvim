local M = {}

local NAMES = {
  "clear",
  "clip",
  "comment",
  "copy",
  "delete",
  "edit",
  "export",
  "file",
  "help",
  "mode",
  "next",
  "note",
  "prev",
  "previous",
  "reload",
  "summary",
  "yank",
}

function M.register()
  vim.api.nvim_create_user_command("Review", function(opts)
    require("review-prompt.core").command(opts)
  end, {
    nargs = "*",
    bang = true,
    range = true,
    desc = "Review comments",
    complete = function(arglead, cmdline, cursorpos)
      local prefix = cmdline:sub(1, cursorpos)
      local rest = prefix:gsub("^%s*Review!?%s*", "")
      if rest:find("%s") then return {} end
      local out = {}
      for _, name in ipairs(NAMES) do
        if name:sub(1, #arglead) == arglead then
          table.insert(out, name)
        end
      end
      return out
    end,
  })
end

return M
