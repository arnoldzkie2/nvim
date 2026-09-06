-- Error Lens-style messages beside the affected code.
vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = "●",
    source = "if_many",
  },
  virtual_lines = false,
  signs = true,
  underline = true,
  severity_sort = true,
  update_in_insert = true,
  float = {
    border = "rounded",
    source = true,
  },
})
