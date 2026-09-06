local path = vim.fn.tempname() .. '.txt'
vim.fn.writefile({ 'already open in a split' }, path)
vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
local existing = vim.api.nvim_get_current_buf()
local config = require('telescope.config').values
local cases = { { 'i', false }, { 'n', false }, { 'i', true }, { 'n', true } }
local index = 0
local function next_case()
  index = index + 1
  local case = cases[index]
  if not case then print('PASS: Enter creates a new tab for an already-open file in both modes and both picker types'); vim.cmd('qa!'); return end
  require('telescope.pickers').new({}, {
    finder = require('telescope.finders').new_table({ results = { path }, entry_maker = function(file)
      return { value = file, filename = file, display = file, ordinal = file, bufnr = case[2] and existing or nil }
    end }),
    sorter = config.generic_sorter({}),
  }):find()
  vim.defer_fn(function()
    local ok, err = xpcall(function()
      config.mappings[case[1]]['<cr>'](vim.api.nvim_get_current_buf())
      assert(#vim.api.nvim_list_tabpages() == 2, 'Enter did not create new tab')
      assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'New tab has unexpected splits')
      assert(vim.api.nvim_get_current_buf() == existing, 'Wrong file opened')
      vim.cmd('tabclose')
    end, debug.traceback)
    if not ok then print(err); vim.cmd('cquit 1'); return end
    vim.schedule(next_case)
  end, 100)
end
next_case()
