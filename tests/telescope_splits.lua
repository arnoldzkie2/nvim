local path = vim.fn.tempname() .. '.txt'
vim.fn.writefile({ 'direction test' }, path)
local original = vim.api.nvim_get_current_win()
local config = require('telescope.config').values
local cases = {}
for _, kind in ipairs({ 'file', 'buffer' }) do
  for _, key in ipairs({ 'w', 'a', 's', 'd' }) do
    table.insert(cases, { kind = kind, key = key })
  end
end
local index = 0
local function next_case()
  index = index + 1
  local case = cases[index]
  if not case then print('PASS: all four split directions for file and buffer pickers'); vim.cmd('qa!'); return end
  vim.api.nvim_set_current_win(original)
  require('telescope.pickers').new({}, {
    finder = require('telescope.finders').new_table({
      results = { path },
      entry_maker = function(file)
        return { value = file, filename = file, display = file, ordinal = file,
          bufnr = case.kind == 'buffer' and vim.fn.bufadd(file) or nil }
      end,
    }),
    sorter = config.generic_sorter({}),
  }):find()
  vim.defer_fn(function()
    local ok, err = xpcall(function()
      local mode = case.kind == 'file' and 'i' or 'n'
      config.mappings[mode]['<A-' .. case.key .. '>'](vim.api.nvim_get_current_buf())
      local current = vim.api.nvim_get_current_win()
      assert(#vim.api.nvim_list_tabpages() == 1)
      assert(#vim.api.nvim_tabpage_list_wins(0) == 2)
      assert(vim.api.nvim_buf_get_name(0) == path)
      local here = vim.api.nvim_win_get_position(current)
      local there = vim.api.nvim_win_get_position(original)
      local direction_ok = ({
        w = here[1] < there[1], a = here[2] < there[2],
        s = here[1] > there[1], d = here[2] > there[2],
      })[case.key]
      assert(direction_ok, 'Wrong split direction: ' .. case.key)
      vim.api.nvim_win_close(current, true)
    end, debug.traceback)
    if not ok then print(err); vim.cmd('cquit 1'); return end
    vim.schedule(next_case)
  end, 100)
end
next_case()
