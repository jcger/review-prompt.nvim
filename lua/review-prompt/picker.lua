local M = {}

function M.open(comments, on_jump, on_delete, on_edit)
  vim.ui.select(comments, {
    prompt = "Review comments",
    format_item = function(c)
      return string.format("%s  →  %s", c.ref, c.text)
    end,
  }, function(c, idx)
    if not c then return end

    vim.ui.select({ "Jump", "Delete", "Edit" }, { prompt = "Action" }, function(action)
      if not action then return end
      if action == "Jump" then
        on_jump(c, idx)
      elseif action == "Delete" then
        on_delete(c, idx)
      elseif action == "Edit" then
        on_edit(c, idx)
      end
    end)
  end)
end

return M
