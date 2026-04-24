if vim.g.loaded_review_prompt then return end
vim.g.loaded_review_prompt = 1

-- Auto-setup with defaults if the user doesn't call setup() themselves.
-- VimEnter gives lazy.nvim / packer time to process user config first.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if not vim.g.review_prompt_did_setup then
      require("review-prompt").setup()
    end
  end,
})
