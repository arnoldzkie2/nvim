require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "vim", "vimdoc", "query", "javascript", "typescript", "python", "bash", "json", "html", "css" },
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
