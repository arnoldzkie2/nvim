local map = vim.keymap.set

-- Your existing mappings
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Arrow key mappings
map({"n", "i"}, "<A-w>", "<Up>", { desc = "Move up" })
map({"n", "i"}, "<A-s>", "<Down>", { desc = "Move down" })
map({"n", "i"}, "<A-a>", "<Left>", { desc = "Move left" })
map({"n", "i"}, "<A-d>", "<Right>", { desc = "Move right" })

-- Cut, Copy, Paste, Undo
map({"n", "i"}, "<C-x>", "<ESC>ddi", { desc = "Cut" })
map({"n", "i"}, "<C-c>", "<ESC>yyi", { desc = "Copy" })
map({"n", "i"}, "<C-v>", "<ESC>pi", { desc = "Paste" })
map({"n", "i"}, "<C-z>", "<ESC>ui", { desc = "Undo" })

-- Telescope
map({"n","i"}, "<C-e>", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map({"n","i"}, "<C-d>", "<cmd>Telescope buffers<cr>", { desc = "Search open buffers" })
map({"n","i"}, "<C-k>", "<cmd>tabnext<cr>", { desc = "Next tab" })
map({"n","i"}, "<C-j>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map({"n", "i"}, "<C-q>", "<cmd>tabclose!<cr>", { desc = "Force close tab" })


