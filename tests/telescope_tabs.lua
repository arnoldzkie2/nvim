local path = vim.fn.tempname() .. '.txt'
vim.fn.writefile({ 'already open in a split' }, path)
vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
local existing = vim.api.nvim_get_current_buf()
local existing_win = vim.api.nvim_get_current_win()
local existing_tab = vim.api.nvim_get_current_tabpage()
vim.cmd('tabnew')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'picker origin' })
local origin_tab = vim.api.nvim_get_current_tabpage()
local config = require('telescope.config').values
local cases = {}
for _, mode in ipairs({ 'i', 'n' }) do
  for _, buffer_entry in ipairs({ false, true }) do
    for _, already_open in ipairs({ true, false }) do
      table.insert(cases, { mode, buffer_entry, already_open })
    end
  end
end
local index = 0
local function next_case()
  index = index + 1
  local case = cases[index]
  if not case then vim.fn.delete(path); print('PASS: Enter reuses tabs, opens new files, and enters Insert mode in both picker modes and types'); vim.cmd('qa!'); return end
  vim.api.nvim_set_current_tabpage(origin_tab)
  local selected_path = case[3] and path or (vim.fn.tempname() .. '.txt')
  if not case[3] then vim.fn.writefile({ 'new file' }, selected_path) end
  local selected_buf = case[3] and existing or vim.fn.bufadd(selected_path)
  require('telescope.pickers').new({}, {
    finder = require('telescope.finders').new_table({ results = { selected_path }, entry_maker = function(file)
      return { value = file, filename = file, display = file, ordinal = file, bufnr = case[2] and selected_buf or nil }
    end }),
    sorter = config.generic_sorter({}),
  }):find()
  vim.defer_fn(function()
    local ok, err = xpcall(function()
      config.mappings[case[1]]['<cr>'](vim.api.nvim_get_current_buf())
    end, debug.traceback)
    if not ok then print(err); vim.cmd('cquit 1'); return end
    vim.defer_fn(function()
      local ok, err = xpcall(function()
        assert(vim.api.nvim_get_mode().mode == 'i', 'Telescope did not enter Insert mode: ' .. vim.api.nvim_get_mode().mode)
        assert(vim.api.nvim_get_current_buf() == selected_buf, 'Wrong file opened')
        if case[3] then
          assert(#vim.api.nvim_list_tabpages() == 2, 'Enter created a duplicate tab')
          assert(vim.api.nvim_get_current_tabpage() == existing_tab, 'Wrong tab focused')
          assert(vim.api.nvim_get_current_win() == existing_win, 'Wrong split focused')
        else
          assert(#vim.api.nvim_list_tabpages() == 3, 'Enter did not create a new tab')
          assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'New tab has unexpected splits')
          vim.cmd('tabclose')
          vim.fn.delete(selected_path)
        end
      end, debug.traceback)
      if not ok then print(err); vim.cmd('cquit 1'); return end
      vim.schedule(next_case)
    end, 30)
  end, 100)
end
next_case()

vim.api.nvim_feedkeys('i', 'xt!', false)
