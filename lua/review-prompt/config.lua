local M = {}

M.defaults = {
  keymaps = {
    add = "<leader>rc",
    edit = "<leader>re",
    delete = "<leader>rd",
    manage = "<leader>rl",
    export = "<leader>ry",
    mode = "<leader>rr",
  },
  -- Prefix for the review-level note while review mode is on. `;c` matches tuicr.
  review_leader = ";",
  review_maps = {
    comment = "c",
    file = "C",
    note = "c",
    delete = "dd",
    edit = "i",
    edit_end = "A",
    clip = "y",
    yank = "Y",
    next = "m",
    prev = "M",
    help = "?",
    visual_confirm = "<CR>",
  },
  -- { "issue", "suggestion" } or { { id = "issue", definition = "must fix" } }
  comment_types = {},
  data_dir = vim.fn.stdpath("data") .. "/review-prompt",
  highlight = "DiagnosticWarn",
  input_prompt = "",
  preamble = "Notes:",
}

M.options = vim.deepcopy(M.defaults)

return M
