vim.g.mapleader = " "     -- Set leader to space (most common)

-- Render the theme palette accurately in true-color terminals.
vim.opt.termguicolors = true

-- Basic quality of life settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
-- Share copies, cuts, and pastes with desktop applications.
vim.opt.clipboard = "unnamedplus"
-- Let arrow keys (including Alt+A/D) cross line boundaries in all editing modes.
vim.opt.whichwrap:append("<,>,[,]")
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
