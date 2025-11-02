local map = vim.keymap.set

-- General
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Arrow key mappings
map({"n", "i", "v"}, "<A-w>", "<Up>", { desc = "Move up" })
map({"n", "i", "v"}, "<A-s>", "<Down>", { desc = "Move down" })
map({"n", "i", "v"}, "<A-a>", "<Left>", { desc = "Move left" })
map({"n", "i", "v"}, "<A-d>", "<Right>", { desc = "Move right" })

-- Shortcuts
map({"n", "i"}, "<C-x>", "<ESC>ddi", { desc = "Cut" })
map({"n", "i"}, "<C-c>", "<ESC>yyi", { desc = "Copy" })
map({"n", "i"}, "<C-v>", "<ESC>pi", { desc = "Paste" })
map({"n", "i"}, "<C-z>", "<ESC>ui", { desc = "Undo" })
map({"n", "i"}, "<A-q>", "<ESC>mzyykp`zi", { desc = "Duplicate line above" })
map({"n", "i"}, "<A-e>", "<ESC>mzyyp`zi", { desc = "Duplicate line below" })

-- Telescope
map({"n","i"}, "<C-e>", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map({"n","i"}, "<C-d>", "<cmd>Telescope buffers<cr>", { desc = "Search open buffers" })
map({"n","i"}, "<C-k>", "<cmd>tabnext<cr>", { desc = "Next tab" })
map({"n","i"}, "<C-j>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map({"n", "i"}, "<C-q>", "<cmd>tabclose!<cr>", { desc = "Force close tab" })

-- NerdTree
vim.keymap.set("n", "<S-n>", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })


