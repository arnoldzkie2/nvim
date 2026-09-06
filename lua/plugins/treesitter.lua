require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "vim", "vimdoc", "query", "javascript", "typescript", "python", "bash", "json", "html", "css" },
  -- The bootstrap must wait for compilation before checking installed parsers.
  sync_install = vim.g.nvim_setup == true,
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
