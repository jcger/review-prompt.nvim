local M = {}

M.defaults = {
  keymaps = {
    add    = "<leader>rc",
    manage = "<leader>rl",
    export = "<leader>ry",
  },
  data_dir      = vim.fn.stdpath("data") .. "/review-prompt",
  highlight     = "DiagnosticWarn",
  input_prompt  = "",
  preamble      = "Notes:",
}

M.options = vim.deepcopy(M.defaults)

return M
