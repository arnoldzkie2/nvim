local function fail(err)
  print(err)
  vim.cmd('cquit 1')
end
local ok, err = xpcall(function()
  local original = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(original, 0, -1, false, { 'first line', 'target_variable = 42', 'last line' })
  local builtin = require('telescope.builtin')
  local get_clients = vim.lsp.get_clients
  local search_lines = builtin.current_buffer_fuzzy_find
  local captured
  vim.lsp.get_clients = function(opts)
    return { {} }
  end
  builtin.current_buffer_fuzzy_find = function(opts) captured = opts end
  for _, mode in ipairs({ 'n', 'i', 'x' }) do
    vim.fn.maparg('<A-l>', mode, false, true).callback()
    assert(captured and captured.attach_mappings, 'Missing text picker or in-place Enter override')
  end
  vim.lsp.get_clients = get_clients
  builtin.current_buffer_fuzzy_find = search_lines

  vim.fn.maparg('<A-l>', 'n', false, true).callback()
  local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
  picker:set_prompt('42')
  vim.defer_fn(function()
    local selected_ok, selected_err = xpcall(function()
      local prompt = vim.api.nvim_get_current_buf()
      local entry = require('telescope.actions.state').get_selected_entry()
      assert(entry and entry.lnum == 2, 'Text search did not find numeric value')
      local enter = vim.fn.maparg('<CR>', 'i', false, true)
      assert(enter.buffer == 1 and enter.callback, 'Picker Enter override missing')
      enter.callback()
      assert(vim.api.nvim_get_current_buf() == original)
      assert(vim.wait(500, function() return vim.api.nvim_win_get_cursor(0)[1] == 2 end, 10), "Cursor did not jump to result")
      assert(#vim.api.nvim_list_tabpages() == 1, 'Current-file search opened a new tab')
      assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'Current-file search left extra windows')
      print('PASS: Alt+L text search with LSP available, value matching, and in-place Enter navigation')
      vim.cmd('qa!')
    end, debug.traceback)
    if not selected_ok then fail(selected_err) end
  end, 150)
end, debug.traceback)
if not ok then fail(err) end
