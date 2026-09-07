local function keys(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), 'xt', false)
end
local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function reset(text)
  if vim.b.visual_multi then keys('<Esc>') end
  vim.cmd('enew!')
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, text)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end
local function check()
  reset({ 'foo + foo + foo' })
  keys('<C-d>')
  assert(vim.deep_equal(lines(), { 'foo + foo + foo' }), 'Selection changed text')
  keys('<C-d>bar<Esc>')
  assert(vim.deep_equal(lines(), { 'bar + bar + foo' }), vim.inspect(lines()))
  assert(not vim.b.visual_multi, 'One Escape did not exit multicursor')
  assert(vim.fn.maparg('n', 'n') == 'gt', 'Normal tab mapping not restored')
  assert(vim.fn.maparg('b', 'n') == '', 'Typing map leaked into normal editing')

  for _, case in ipairs({
    { 'foo foo', 0, 'bar', 'bar foo' },
    { 'prefix foo suffix', 7, 'bar', 'prefix bar suffix' },
    { 'prefix foo', 7, 'bar', 'prefix bar' },
    { 'foo', 0, 'bar', 'bar' },
    { 'foo foo', 0, '<BS>bar', 'bar foo' },
  }) do
    reset({ case[1] })
    vim.api.nvim_win_set_cursor(0, { 1, case[2] })
    keys('<C-d>' .. case[3]
      .. '<Cmd>lua assert(not vim.b.visual_multi, "Single replacement kept multicursor"); assert(vim.api.nvim_get_mode().mode == "i", "Single replacement left Insert mode")<CR><Esc>')
    assert(vim.deep_equal(lines(), { case[4] }), 'Single replacement failed: ' .. vim.inspect(lines()))
    keys('u')
    assert(vim.deep_equal(lines(), { case[1] }), 'Single replacement did not undo together')
  end
  for _, replacement in ipairs({ 'cat', '123', '_value', '<tag>', 'hello world' }) do
    reset({ 'foo', 'foo', 'foo' })
    keys('<C-d><C-d><C-d>' .. replacement .. '<Esc>')
    assert(vim.deep_equal(lines(), { replacement, replacement, replacement }), vim.inspect(lines()))
  end
  reset({ 'foo foo' })
  keys('i<C-d><C-d>new<Esc>')
  assert(vim.deep_equal(lines(), { 'new new' }), 'Insert-mode entry failed')
  reset({ 'x foo foo' })
  keys('w' .. 'i<C-d><C-d>new<Esc>')
  assert(vim.deep_equal(lines(), { 'x new new' }), 'Insert caret selected the preceding word')
  reset({ 'x x' })
  keys('i<C-d><C-d>new<Esc>')
  assert(vim.deep_equal(lines(), { 'new new' }), 'Single-character Insert selection failed')
  reset({ 'foo foo' })
  keys('<C-d><C-d><Esc>')
  assert(vim.deep_equal(lines(), { 'foo foo' }), 'Escape should cancel unchanged selections')
  reset({ 'foo foo' })
  keys('<C-d><C-d><BS>x<Esc>')
  assert(vim.deep_equal(lines(), { 'x x' }), 'Backspace did not replace selections')
  reset({ 'foo foo' })
  keys('<Plug>(VM-Add-Cursor-At-Pos)')
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  keys('<Plug>(VM-Add-Cursor-At-Pos)!<Esc>')
  assert(vim.deep_equal(lines(), { '!foo !foo' }), 'Direct typing at empty cursors failed')
  reset({ 'foo foo foo' })
  keys('<C-S-l>all<Esc>')
  assert(vim.deep_equal(lines(), { 'all all all' }), 'Select all failed')
  reset({ 'foo foo' })
  keys('<C-d><C-d>new<Esc>u')
  assert(vim.deep_equal(lines(), { 'foo foo' }), 'Undo did not restore selections together')
  reset({ 'foo foo' })
  keys('<C-d>new<C-z>')
  assert(vim.deep_equal(lines(), { 'foo foo' }), 'Ctrl+Z did not undo the single-selection edit')
  assert(not vim.b.visual_multi, 'Ctrl+Z left multicursor active')
  assert(vim.fn.maparg('b', 'n') == '', 'Ctrl+Z left temporary typing mappings')
  assert(vim.fn.maparg('<C-z>', 'n', false, true).buffer == 0, 'Normal undo mapping not restored')
  assert(vim.fn.maparg('<C-z>', 'i', false, true).buffer == 0, 'Insert undo mapping not restored')
  -- Ctrl+Z also exits when selections are active before typing.
  keys('<C-d><C-z>')
  assert(not vim.b.visual_multi, 'Ctrl+Z left a single unedited selection active')
  for _, count in ipairs({ 2, 3 }) do
    reset({ 'foo foo foo' })
    keys(string.rep('<C-d>', count) .. 'new<C-z>')
    assert(vim.deep_equal(lines(), { 'foo foo foo' }), 'Multi-selection undo did not restore text')
    assert(vim.b.visual_multi, 'Undo exited with multiple cursors')
    assert(vim.fn.eval('len(b:VM_Selection.Regions)') == count, 'Undo lost selected cursors')
    keys('bar<Esc>')
    local expected = count == 2 and 'bar bar foo' or 'bar bar bar'
    assert(vim.deep_equal(lines(), { expected }), 'Typing after undo failed: ' .. vim.inspect(lines()))
    reset({ 'foo foo foo' })
    keys(string.rep('<C-d>', count) .. '<C-z>')
    assert(vim.b.visual_multi, 'Undo exited unedited multiple selections')
    assert(vim.fn.eval('len(b:VM_Selection.Regions)') == count, 'Undo lost unedited selections')
    keys('<Esc>')
  end
  for _, count in ipairs({ 2, 3 }) do
    for _, typing in ipairs({ false, true }) do
      reset(vim.fn['repeat']({ 'foo' }, count))
      keys(string.rep('<C-d>', count))
      local steps = typing and { '<CR>', 'next', '<CR>', 'last', '<Esc>' } or { 'next', '<CR>', 'last', '<Esc>' }
      local step = 0
      local function send_step()
        step = step + 1
        require('blink.cmp').hide()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(steps[step], true, false, true), 'm', false)
        if step < #steps then vim.defer_fn(send_step, 30) end
      end
      vim.defer_fn(send_step, 30)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(typing and 'bar' or '<CR>', true, false, true), 'xt!', false)
      local expected = {}
      for _ = 1, count do
        vim.list_extend(expected, { typing and 'bar' or '', 'next', 'last' })
      end
      assert(vim.deep_equal(lines(), expected), 'Enter changed text incorrectly: ' .. vim.inspect(lines()))
    end
  end
  reset({ 'foo foo' })
  local original = function() end
  vim.keymap.set('n', 'b', original, { buffer = true })
  keys('<C-d><C-d>bar<Esc>')
  assert(vim.fn.maparg('b', 'n', false, true).callback == original, 'Buffer-local callback not restored')
  reset({ 'whole line', 'keep this' })
  keys('<C-l>replacement<Esc>')
  assert(vim.deep_equal(lines(), { 'replacement', 'keep this' }), 'Whole-line direct replacement failed')
  reset({ 'foo', 'foo', 'barrel' })
  keys('<C-d><C-d>')
  local completion_error
  vim.defer_fn(function()
    local ok, err = xpcall(function()
      local cmp = require('blink.cmp')
      cmp.show({ providers = { 'buffer' } })
      local selected
      assert(vim.wait(5000, function()
        for index, item in ipairs(cmp.get_items()) do
          if item.label == 'barrel' then selected = index; return true end
        end
        return false
      end, 50), 'Completion candidate missing')
      local accepted = false
      cmp.accept({ index = selected, force = true, callback = function() accepted = true end })
      assert(vim.wait(5000, function() return accepted end, 50), 'Completion acceptance failed')
    end, debug.traceback)
    if not ok then completion_error = err end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'm', false)
  end, 100)
  vim.api.nvim_feedkeys('ba', 'xt!', false)
  assert(not completion_error, completion_error)
  assert(vim.deep_equal(lines(), { 'barrel', 'barrel', 'barrel' }), 'Completion did not update all cursors: ' .. vim.inspect(lines()))
  for _, case in ipairs({
    { 'w', { 'top text', 'fo!o', 'foo', 'bottom' }, { 'top text', 'foo!', 'bar', 'bottom' } },
    { 'a', { 'top text', 'foo', 'f!oo', 'bottom' }, { 'top text', 'foo', 'ba!r', 'bottom' } },
    { 's', { 'top text', 'foo', 'foo', 'bo!ttom' }, { 'top text', 'foo', 'bar', 'bot!tom' } },
    { 'd', { 'top text', 'foo', 'foo!', 'bottom' }, { 'top text', 'foo', 'bar', '!bottom' } },
  }) do
    for _, typing in ipairs({ false, true }) do
      reset({ 'top text', 'foo', 'foo', 'bottom' })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      keys('<C-d>' .. (typing and 'bar' or '') .. '<A-' .. case[1] .. '>'
        .. '<Cmd>lua assert(not vim.b.visual_multi, "Movement left multicursor active"); assert(vim.api.nvim_get_mode().mode == "i", "Movement did not enter Insert mode")<CR>'
        .. '!<Esc>')
      assert(vim.deep_equal(lines(), case[typing and 3 or 2]), 'Alt+' .. case[1] .. ': ' .. vim.inspect(lines()))
      assert(vim.fn.maparg('<A-' .. case[1] .. '>', 'i', false, true).buffer == 0, 'Temporary movement map leaked')
    end
  end
  for _, letter in ipairs({ 'w', 'a', 's', 'd' }) do
    for _, typing in ipairs({ false, true }) do
      reset({ 'top text', 'foo', 'middle text', 'foo', 'bottom text' })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      keys('<C-d><C-d>' .. (typing and 'bar' or '') .. '<A-' .. letter .. '>'
        .. '<Cmd>lua assert(vim.b.visual_multi, "Multiple cursors exited"); assert(vim.fn.eval("len(b:VM_Selection.Regions)") == 2, "Cursor count changed"); assert(vim.api.nvim_get_mode().mode == "i", "Movement did not enter Insert mode")<CR>'
        .. '!<Esc>')
      local text = table.concat(lines(), '\n')
      local _, markers = text:gsub('!', '')
      assert(markers == 2, 'Typing after Alt+' .. letter .. ' did not update both cursors: ' .. text)
    end
  end
  for _, direction in ipairs({ { '<A-w>', 1 }, { '<A-s>', 3 } }) do
    reset({ '  above text', '', '  below text' })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    keys('i' .. direction[1] .. '!<Esc>')
    assert(lines()[direction[2]]:sub(1, 1) == '!', 'Blank-line movement did not land at the beginning')
  end
  print('PASS: Ctrl+D direct replacement, Insert-mode entry, select all, punctuation/digits, Escape, Backspace, undo, line selection, and mapping cleanup')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
