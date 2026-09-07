local workspace = vim.fn.tempname()
local root = workspace .. '/apps/api'
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(lines, path)
end
local function check()
  vim.fn.mkdir(workspace .. '/.git', 'p')
  vim.fn.system({ 'python3', '-m', 'venv', '--without-pip', workspace .. '/.venv' })
  assert(vim.v.shell_error == 0, 'Could not create test environment')
  local python = workspace .. '/.venv/bin/python'
  local site = vim.fn.system({ python, '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))' }):gsub('%s+$', '')
  write(root .. '/pyproject.toml', { '[project]', 'name = "autoimport-test"', 'version = "0.1.0"' })
  write(root .. '/src/api/__init__.py', {})
  write(root .. '/src/api/core/__init__.py', {})
  write(root .. '/src/api/test.py', {
    'num1 = "Test1"', 'num_typed: int = 2', 'num_left, num_right = 3, 4',
    'async def num_async(): pass', 'def num_function(): pass', 'class NumClass: pass',
    'class Example:', '    num_member = 2', 'def example():', '    num_local = 3',
  })
  write(root .. '/src/api/core/values.py', { 'num_deep = 5' })
  write(site .. '/sample_library/__init__.py', { 'from .deep.values import library_value as library_value' })
  write(site .. '/sample_library/deep/__init__.py', {})
  write(site .. '/sample_library/deep/values.py', {
    'library_value: int = 7', 'def library_function(): pass',
    'async def library_async(): pass', 'class LibraryClass: pass', 'LIBRARY_CONSTANT = 8',
  })
  local sibling = workspace .. '/packages/shared/src'
  write(sibling .. '/sharedlib/__init__.py', {})
  write(sibling .. '/sharedlib/values.py', { 'shared_value = 9' })
  write(site .. '/sharedlib.pth', { sibling })
  local original = { '#!/usr/bin/env python3', '"""Module documentation."""', 'from __future__ import annotations', '', 'nu' }
  write(root .. '/src/api/main.py', original)
  vim.cmd.edit(root .. '/src/api/main.py')
  local bufnr = vim.api.nvim_get_current_buf()
  local client
  assert(vim.wait(15000, function()
    client = vim.lsp.get_clients({ bufnr = bufnr, name = 'ty' })[1]
    return client and client.initialized
  end, 50), 'ty did not attach')
  assert(client.config.settings.ty.configuration.environment.python == python, 'Wrong environment')
  assert(client.config.settings.ty.diagnosticMode == 'off', 'Duplicate diagnostics enabled')
  local function complete(lines, row, col)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local result = client:request_sync('textDocument/completion', {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) }, position = { line = row - 1, character = col },
    }, 15000, bufnr)
    assert(result and not result.err, vim.inspect(result))
    local completion = result.result or {}
    return completion.items or completion
  end
  local function find_import(prefix, name, module)
    for _, item in ipairs(complete({ prefix }, 1, #prefix)) do
      if item.label == name then
        for _, edit in ipairs(item.additionalTextEdits or {}) do
          if edit.newText:find('from ' .. module .. ' import ' .. name, 1, true) then return item end
        end
      end
    end
    error('Missing auto-import: ' .. name .. ' from ' .. module)
  end
  for _, name in ipairs({ 'num1', 'num_typed', 'num_left', 'num_right', 'num_async', 'num_function', 'NumClass' }) do
    find_import(name:sub(1, 2), name, 'api.test')
  end
  find_import('num_de', 'num_deep', 'api.core.values')
  for _, name in ipairs({ 'library_value', 'library_function', 'library_async', 'LibraryClass', 'LIBRARY_CONSTANT' }) do
    find_import(name:sub(1, 5), name, name == 'library_value' and 'sample_library' or 'sample_library.deep.values')
  end
  find_import('library_v', 'library_value', 'sample_library')
  find_import('shared_v', 'shared_value', 'sharedlib.values')
  find_import('date', 'datetime', 'datetime')
  for _, item in ipairs(complete(original, 5, 2)) do
    assert(item.label ~= 'num_local' and item.label ~= 'num_member', 'Function/class-local name auto-imported')
    if item.label == 'num1' then
      assert(item.additionalTextEdits[1].range.start.line >= 3, 'Import inserted before future import')
    end
  end
  for _, item in ipairs(complete({ 'from api.test import num1', 'nu' }, 2, 2)) do
    if item.label == 'num1' then assert(not item.additionalTextEdits or #item.additionalTextEdits == 0, 'Duplicate import') end
  end
  for _, line in ipairs({ '# nu', '"nu"', 'obj.nu' }) do
    for _, item in ipairs(complete({ line }, 1, line == '"nu"' and 3 or #line)) do
      assert(item.label ~= 'num1' or not item.additionalTextEdits, 'Auto-import in comment, string, or member access')
    end
  end
  assert(vim.fn.bufnr(root .. '/src/api/test.py') == -1, 'Source file must remain unopened')
  assert(vim.fn.bufnr(site .. '/sample_library/deep/values.py') == -1, 'Library must remain unopened')
  -- Exercise the actual configured Blink LSP source and its acceptance path.
  for _, case in ipairs({ { original, 'num1', 'api.test' }, { { 'nu' }, 'num1', 'api.test' },
    { { 'library_v' }, 'library_value', 'sample_library' } }) do
    local lines, name, module = unpack(case)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, #lines[#lines] - 1 })
    local acceptance_error
    vim.defer_fn(function()
      local ok, err = xpcall(function()
        local cmp = require('blink.cmp')
        cmp.show({ providers = { 'lsp' } })
        local selected
        assert(vim.wait(10000, function()
          for index, item in ipairs(cmp.get_items()) do
            if item.label == name and item.client_id == client.id then
              for _, edit in ipairs(item.additionalTextEdits or {}) do
                if edit.newText:find('from ' .. module .. ' import ' .. name, 1, true) then
                  selected = index
                  return true
                end
              end
            end
          end
          return false
        end, 50), 'Blink did not show ' .. name)
        local accepted = false
        assert(cmp.accept({ index = selected, force = true, callback = function() accepted = true end }), 'Blink did not accept')
        assert(vim.wait(5000, function() return accepted end, 50), 'Acceptance timed out')
      end, debug.traceback)
      if not ok then acceptance_error = err end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
    end, 50)
    vim.api.nvim_feedkeys('A', 'nx!', false)
    assert(not acceptance_error, acceptance_error)
    local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    assert(text:find('from ' .. module .. ' import ' .. name, 1, true), text)
    assert(text:sub(-#name - 1) == '\n' .. name, text)
  end
  -- Switching interpreters must update both engines and stop suggesting
  -- packages that exist only in the previous environment.
  local other = workspace .. '/other-env'
  vim.fn.system({ 'python3', '-m', 'venv', '--without-pip', other })
  assert(vim.v.shell_error == 0, 'Could not create alternate environment')
  assert(vim.wait(15000, function()
    local pyright = vim.lsp.get_clients({ bufnr = bufnr, name = 'pyright' })[1]
    return pyright and pyright.initialized
  end, 50), 'Pyright did not attach')
  vim.cmd('LspPyrightSetPythonPath ' .. other .. '/bin/python')
  local function wait_for_ty(python_path)
    assert(vim.wait(15000, function()
      for _, attached in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = 'ty' })) do
        if attached.initialized and attached.settings.ty.configuration.environment.python == python_path then
          client = attached
          return true
        end
      end
      return false
    end, 50), 'ty did not restart with the selected environment')
  end
  wait_for_ty(other .. '/bin/python')
  for _, attached in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if attached.name == 'pyright' then
      assert(attached.settings.python.pythonPath == other .. '/bin/python', 'Pyright interpreter not updated')
    elseif attached.name == 'ty' then
      assert(attached.settings.ty.configuration.environment.python == other .. '/bin/python', 'ty interpreter not updated')
    end
  end
  assert(vim.wait(10000, function()
    for _, item in ipairs(complete({ 'library_v' }, 1, 9)) do
      if item.label == 'library_value' then return false end
    end
    return true
  end, 100), 'Completions leaked from the previous environment')
  vim.cmd('LspPyrightSetPythonPath ' .. python)
  wait_for_ty(python)
  assert(vim.wait(10000, function()
    return pcall(find_import, 'library_v', 'library_value', 'sample_library')
  end, 100), 'Library completion did not return after restoring interpreter')
  print('PASS: ty auto-imports project variables/functions/classes, annotations, tuple assignments, async functions, deep libraries, re-exports, editable sibling packages, stdlib, and Blink acceptance')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(workspace, 'rf')
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
