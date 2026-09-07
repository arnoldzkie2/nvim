-- These options must be set before vim-visual-multi loads.
vim.g.VM_default_mappings = 0
vim.g.VM_maps = {
  ["Find Under"] = "<C-d>",
  ["Find Subword Under"] = "<C-d>",
  ["Select All"] = "<C-S-l>",
  ["Visual All"] = "<C-S-l>",
  ["Mouse Cursor"] = "<A-LeftMouse>",
}

-- Enter multiple selection from Insert mode as well.
vim.keymap.set("i", "<C-d>", function()
  -- Escape moves left in Insert mode; keep selection on the word at the caret.
  local leave = vim.fn.col(".") > 1 and "<Esc>l" or "<Esc>"
  return leave .. "<Plug>(VM-Find-Under)"
end, { expr = true, desc = "Select word / add next matching word" })

vim.keymap.set("i", "<C-S-l>", "<Esc><Plug>(VM-Select-All)", {
  desc = "Select all matching words",
})
vim.keymap.set("i", "<A-LeftMouse>", "<Esc><Plug>(VM-Mouse-Cursor)", {
  desc = "Add cursor at mouse position",
})

-- Resolve the regular movement mapping after VM has restored the buffer maps.
for _, letter in ipairs({ "w", "a", "s", "d" }) do
  vim.keymap.set("i", "<Plug>(VM-Resume-Move-" .. letter .. ")", "<A-" .. letter .. ">", { remap = true })
end

-- Select the current line as an editable region.
vim.keymap.set({ "n", "i" }, "<C-l>", "<Esc>V<Plug>(VM-Visual-Add)", {
  desc = "Select entire line",
})

-- VM reapplies its buffer mappings when entering multiple-cursor editing.
-- Give Blink priority while its menu is open, then fall back to VM's actions.
local group = vim.api.nvim_create_augroup("MultiCursorCompletion", { clear = true })
local sessions = {}

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "visual_multi_start",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    sessions[bufnr] = { original = {}, changed = {} }
    vim.b.multicursor_undo_regions = vim.empty_dict()
    for _, mode in ipairs({ "n", "i" }) do
      sessions[bufnr].original[mode] = vim.api.nvim_buf_get_keymap(bufnr, mode)
    end
  end,
})

local function temporary_map(mode, key, action, options)
  local bufnr = vim.api.nvim_get_current_buf()
  local session = sessions[bufnr]
  if not session then return end
  session.changed[mode] = session.changed[mode] or {}
  session.changed[mode][key] = true
  vim.keymap.set(mode, key, action, vim.tbl_extend("force", options or {}, { buffer = bufnr, silent = true }))
end

local function has_multiple_cursors()
  return vim.fn.eval('len(get(get(b:, "VM_Selection", {}), "Regions", []))') > 1
end

local function type_at_selections(text)
  -- Changing a region deletes it only when typing starts. Empty cursors just insert.
  local selecting = vim.g.Vm and vim.g.Vm.extend_mode == 1
  local change = selecting and "<Plug>(VM-c)" or "<Plug>(VM-i)"
  if not has_multiple_cursors() then
    if text == "<Plug>(VM-I-Return)" then text = "<CR>" end
    return change .. "<Plug>(VM-Single-Insert)" .. text
  end
  return "<Plug>(VM-Snapshot-Selections)" .. change .. text
end

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "visual_multi_exit",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local session = sessions[bufnr]
    if not session then return end
    for mode, keys in pairs(session.changed) do
      for key in pairs(keys) do pcall(vim.keymap.del, mode, key, { buffer = bufnr }) end
      -- VM removes its own mappings first; restore the buffer's original mappings.
      for _, mapping in ipairs(session.original[mode]) do
        vim.fn.mapset(mode, false, mapping)
      end
    end
    vim.b.multicursor_undo_regions = nil
    sessions[bufnr] = nil
  end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args) sessions[args.buf] = nil end,
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "visual_multi_mappings",
  callback = function()
    temporary_map("n", "<Plug>(VM-Snapshot-Selections)", function()
      -- VM's change command backs up after deleting the selected text. Keep
      -- the original geometry too, so undo restores editable word selections.
      vim.cmd([[
        let b:multicursor_undo_regions[undotree().seq_cur] = {
          \ 'regions': deepcopy(b:VM_Selection.Regions), 'X': g:Vm.extend_mode }
      ]])
    end)
    temporary_map("n", "<Plug>(VM-Undo-Selections)", function()
      vim.fn["vm#commands#undo"]()
      vim.cmd([[
        if has_key(b:multicursor_undo_regions, undotree().seq_cur)
          call b:VM_Selection.Global.erase_regions()
          let b:VM_Selection.Regions = deepcopy(b:multicursor_undo_regions[undotree().seq_cur].regions)
          let g:Vm.extend_mode = b:multicursor_undo_regions[undotree().seq_cur].X
          call b:VM_Selection.Global.update_and_select_region()
        endif
      ]])
    end)
    -- While selections/cursors are active, printable keys type instead of
    -- running Normal-mode commands. Plug mappings keep VM's edit/undo handling.
    for byte = 32, 126 do
      local character = string.char(byte)
      local key = character == "<" and "<lt>" or character
      -- VM uses :normal ^ when splitting lines; leave that command available.
      if character ~= "^" then
        temporary_map("n", key, function() return type_at_selections(character) end, {
          expr = true, nowait = true, desc = "Replace multicursor selections with typed text",
        })
      end
    end
    for _, key in ipairs({ "<BS>", "<Del>" }) do
      temporary_map("n", key, function()
        local selecting = vim.g.Vm and vim.g.Vm.extend_mode == 1
        return type_at_selections(selecting and "" or key)
      end, { expr = true, desc = "Delete multicursor selections" })
    end
    temporary_map("n", "<CR>", function()
      return type_at_selections("<Plug>(VM-I-Return)")
    end, { expr = true })
    temporary_map("n", "<Tab>", function() return type_at_selections("<Tab>") end, { expr = true })
    temporary_map("i", "<Plug>(VM-Single-Insert)", function()
      local resume = vim.fn.col(".") > 1 and "a" or "i"
      return "<Esc><Plug>(VM-Exit)" .. resume
    end, { expr = true })
    temporary_map("i", "<Esc>", "<Esc><Plug>(VM-Exit)", { desc = "Finish multicursor editing" })
    -- Preserve VM's region-aware undo while two or more cursors are active.
    for _, mode in ipairs({ "n", "i" }) do
      temporary_map(mode, "<C-z>", function()
        local leave = mode == "i" and "<Esc>" or ""
        if has_multiple_cursors() then return leave .. "<Plug>(VM-Undo-Selections)" end
        return leave .. "<Plug>(VM-Exit)<Cmd>undo<CR>i"
      end, { expr = true, desc = "Undo; keep multicursor for multiple selections" })
    end
    for _, direction in ipairs({ { "w", "Up" }, { "a", "Left" }, { "s", "Down" }, { "d", "Right" } }) do
      local key = "<A-" .. direction[1] .. ">"
      local move = "<Plug>(VM-Resume-Move-" .. direction[1] .. ")"
      local multi_move = "<Plug>(VM-I-" .. direction[2] .. "-Arrow)"
      temporary_map("n", key, function()
        if has_multiple_cursors() then return "<Plug>(VM-i)" .. multi_move end
        return "<Plug>(VM-Exit)i" .. move
      end, { expr = true, desc = "Move and type; exit multicursor only for one selection" })
      temporary_map("i", key, function()
        if has_multiple_cursors() then return multi_move end
        local resume = vim.fn.col(".") > 1 and "a" or "i"
        return "<Esc><Plug>(VM-Exit)" .. resume .. move
      end, { expr = true, desc = "Move and type; exit multicursor only for one cursor" })
    end
    local actions = {
      ["<Up>"] = { "select_prev", "<Plug>(VM-I-Up-Arrow)" },
      ["<Down>"] = { "select_next", "<Plug>(VM-I-Down-Arrow)" },
      ["<CR>"] = { "accept", "<Plug>(VM-I-Return)" },
      ["<Tab>"] = { "select_and_accept", "<Tab>" },
    }
    for key, action in pairs(actions) do
      temporary_map("i", key, function()
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
