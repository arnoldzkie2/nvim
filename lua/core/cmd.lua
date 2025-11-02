-- Auto save when stopping typing
vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
  pattern = "*",
  command = "silent! write",
  nested = true
})



