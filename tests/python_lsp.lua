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
  assert(not joined:find('cannot be assigned', 1, true), joined)
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
  -- ty covers indexed bare-name auto-imports in python_autoimport.lua.
  -- Pyright still resolves explicit imports from unopened modules.
  assert(vim.fn.bufnr(root .. '/helper.py') == -1, 'Helper was opened before completion')
  local import_prefix = 'from helper import unique_autoimport_var'
  vim.api.nvim_buf_set_lines(bufnr, 4, 5, false, { import_prefix })
  result = client:request_sync('textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 4, character = #import_prefix }, context = { triggerKind = 1 },
  }, 10000, bufnr)
  assert(vim.iter(result and result.result and (result.result.items or result.result) or {}):any(function(item)
    return item.label == 'unique_autoimport_variable'
  end), 'Cross-file variable import completion missing')
  -- Real errors must disappear after an unsaved fix, without restarting LSP.
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'missing_name' })
  assert(vim.wait(15000, function()
    return vim.iter(vim.diagnostic.get(bufnr)):any(function(d) return d.message:find('missing_name', 1, true) ~= nil end)
  end, 50), 'Real undefined-name error was suppressed')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'missing_name = 1', 'print(missing_name)' })
  assert(vim.wait(15000, function() return #vim.diagnostic.get(bufnr) == 0 end, 50), 'Fixed error remained visible')
  local publish = client.config.handlers['textDocument/publishDiagnostics']
  local version = vim.lsp.util.buf_versions[bufnr]
  local ctx = { client_id = client.id }
  local report = { uri = vim.uri_from_bufnr(bufnr), version = version, diagnostics = {
    { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
      message = 'diagnostic lifecycle fixture', severity = 1 },
  } }
  publish(nil, report, ctx)
  assert(#vim.diagnostic.get(bufnr) == 1, 'Current report rejected')
  publish(nil, { uri = report.uri, version = version - 1, diagnostics = {} }, ctx)
  assert(#vim.diagnostic.get(bufnr) == 1, 'Old empty report cleared current error')
  publish(nil, { uri = report.uri, version = version, diagnostics = {} }, ctx)
  assert(#vim.diagnostic.get(bufnr) == 0, 'Current empty report did not clear error')
  report.version = version - 1
  publish(nil, report, ctx)
  assert(#vim.diagnostic.get(bufnr) == 0, 'Old report resurrected a fixed error')
  report.version = nil
  publish(nil, report, ctx)
  assert(#vim.diagnostic.get(bufnr) == 1, 'Unversioned report rejected')
  publish(nil, { uri = report.uri, diagnostics = {} }, ctx)
  assert(#vim.diagnostic.get(bufnr) == 0, 'Unversioned clear rejected')
  assert(vim.diagnostic.config().virtual_text, 'Inline errors disabled')
  print('PASS: Python attachment, shared monorepo venv, installed-library completion, explicit import completion, Pylance diagnostic defaults, unsaved error clearing, and stale-report rejection')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(workspace, 'rf')
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
