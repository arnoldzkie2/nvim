-- These options must be set before vim-visual-multi loads.
vim.g.VM_default_mappings = 0
vim.g.VM_maps = {
  ["Find Under"] = "<C-d>",
  ["Find Subword Under"] = "<C-d>",
}

-- Enter multiple selection from Insert mode as well.
vim.keymap.set("i", "<C-d>", "<Esc><Plug>(VM-Find-Under)", {
  desc = "Select word / add next matching word",
})

-- Select the current line as an editable region.
vim.keymap.set({ "n", "i" }, "<C-l>", "<Esc>V<Plug>(VM-Visual-Add)", {
  desc = "Select entire line",
})

-- VM reapplies its buffer mappings when entering multiple-cursor editing.
-- Give Blink priority while its menu is open, then fall back to VM's actions.
local group = vim.api.nvim_create_augroup("MultiCursorCompletion", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "visual_multi_mappings",
  callback = function()
    local actions = {
      ["<Up>"] = { "select_prev", "<Plug>(VM-I-Up-Arrow)" },
      ["<Down>"] = { "select_next", "<Plug>(VM-I-Down-Arrow)" },
      ["<CR>"] = { "accept", "<Plug>(VM-I-Return)" },
    }
    for key, action in pairs(actions) do
      vim.keymap.set("i", key, function()
        local cmp = package.loaded["blink.cmp"]
        if cmp and cmp.is_menu_visible() and cmp[action[1]]() then
          return ""
        end
        return action[2]
      end, {
        buffer = true,
        expr = true,
        silent = true,
        desc = "Completion or multiple-cursor " .. action[1],
      })
    end
  end,
})
