if vim.g.loaded_review_prompt then return end
vim.g.loaded_review_prompt = 1

-- Auto-setup with defaults if the user doesn't call setup() themselves.
-- If loaded after VimEnter (e.g. via VeryLazy), set up immediately.
if vim.v.vim_did_enter == 1 then
  if not vim.g.review_prompt_did_setup then
    require("review-prompt").setup()
  end
else
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if not vim.g.review_prompt_did_setup then
        require("review-prompt").setup()
      end
    end,
  })
end
