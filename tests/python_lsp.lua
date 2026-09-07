local workspace = vim.fn.tempname()
local root = workspace .. '/apps/api'
local function check()
  vim.fn.mkdir(root, 'p')
  vim.fn.mkdir(workspace .. '/.git', 'p')
  vim.fn.system({ 'python3', '-m', 'venv', '--without-pip', workspace .. '/.venv' })
  assert(vim.v.shell_error == 0, 'Could not create test environment')
  local site = vim.fn.system({ workspace .. '/.venv/bin/python', '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))' }):gsub('%s+$', '')
  vim.fn.mkdir(site .. '/example_library', 'p')
  vim.fn.writefile({ 'def example_function(value: int) -> int:', '    return value' }, site .. '/example_library/__init__.py')
  vim.fn.writefile({ '[project]', 'name = "python-lsp-test"', 'version = "0.1.0"' }, root .. '/pyproject.toml')
  vim.fn.writefile({ 'import example_library', 'example_library.exa', 'missing_name', 'value: int = "wrong"', 'example_lib' }, root .. '/main.py')
  vim.fn.writefile({ 'def unique_autoimport_function() -> int:', '    return 1', 'unique_autoimport_variable = 42', 'UNIQUE_AUTOIMPORT_CONSTANT = 42', 'class UniqueAutoimportClass:', '    pass' }, root .. '/helper.py')
  vim.cmd.edit(root .. '/main.py')
  local bufnr = vim.api.nvim_get_current_buf()
  local client
  assert(vim.wait(15000, function()
    client = vim.lsp.get_clients({ bufnr = bufnr, name = 'pyright' })[1]
    return client and client.initialized
  end, 50), 'Pyright did not attach')
  assert(client.config.settings.python.pythonPath == workspace .. '/.venv/bin/python', 'Wrong interpreter')
  assert(vim.wait(20000, function() return #vim.diagnostic.get(bufnr) > 0 end, 50), 'No Python diagnostics')
  local messages = vim.tbl_map(function(d) return d.message end, vim.diagnostic.get(bufnr))
  local joined = table.concat(messages, '\n')
  assert(joined:find('missing_name', 1, true), joined)
  assert(joined:find('int', 1, true), joined)
  assert(not joined:find('could not be resolved', 1, true), joined)
  local result = client:request_sync('textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 1, character = 19 },
    context = { triggerKind = 1 },
  }, 10000, bufnr)
  assert(result and result.result, vim.inspect(result))
  local found = false
  for _, item in ipairs(result.result.items or result.result) do
    if item.label == 'example_function' then found = true end
  end
  assert(found, 'Installed-library member completion missing')
  -- The helper must remain unopened: suggestions should come from project analysis.
  assert(vim.fn.bufnr(root .. '/helper.py') == -1, 'Helper was opened before completion')
  for _, symbol in ipairs({ 'unique_autoimport_function', 'UNIQUE_AUTOIMPORT_CONSTANT', 'UniqueAutoimportClass' }) do
    local prefix = symbol:sub(1, -3)
    vim.api.nvim_buf_set_lines(bufnr, 4, 5, false, { prefix })
    vim.wait(300, function() return false end, 50)
    result = client:request_sync('textDocument/completion', {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = { line = 4, character = #prefix }, context = { triggerKind = 1 },
    }, 10000, bufnr)
    found = false
    for _, item in ipairs(result and result.result and (result.result.items or result.result) or {}) do
      if item.label == symbol then
        local resolved = client:request_sync('completionItem/resolve', item, 10000, bufnr)
        local edits = resolved and resolved.result and resolved.result.additionalTextEdits or {}
        assert(vim.iter(edits):any(function(edit)
          return edit.newText:find('from helper import ' .. symbol, 1, true) ~= nil
        end), 'Correct auto-import edit missing for ' .. symbol)
        found = true
      end
    end
    assert(found, 'Unopened-file completion missing for ' .. symbol .. ': ' .. vim.inspect(result))
    assert(vim.fn.bufnr(root .. '/helper.py') == -1, 'Completion opened the helper buffer')
  end
  -- Pyright filters lowercase variables from bare-name auto-imports, but must
  -- suggest them while writing an explicit import from the unopened module.
  local import_prefix = 'from helper import unique_autoimport_var'
  vim.api.nvim_buf_set_lines(bufnr, 4, 5, false, { import_prefix })
  result = client:request_sync('textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 4, character = #import_prefix }, context = { triggerKind = 1 },
  }, 10000, bufnr)
  assert(vim.iter(result and result.result and (result.result.items or result.result) or {}):any(function(item)
    return item.label == 'unique_autoimport_variable'
  end), 'Cross-file variable import completion missing')
  assert(vim.diagnostic.config().virtual_text, 'Inline errors disabled')
  print('PASS: Python attachment, shared monorepo venv, installed-library completion, unopened-file function/constant/class auto-imports and variable import completion, and inline diagnostics')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(workspace, 'rf')
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
