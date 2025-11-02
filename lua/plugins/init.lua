-- ~/.config/nvim/lua/plugins/init.lua

-- Lazy.nvim setup
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin list
require("lazy").setup({
  -- Plugin manager
  "folke/lazy.nvim",

  -- Colorscheme
  {"catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000},

  -- Essential plugins
  "nvim-lua/plenary.nvim",
  "tpope/vim-sleuth", -- Auto detect tab settings

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("plugins.telescope")
    end
  },

})
