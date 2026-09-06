-- Run only through setup.sh: wait for each installation and fail on errors.
local ok, err = xpcall(function()
  vim.g.loaded_wakatime = 1
  vim.g.nvim_setup = true
  vim.opt.loadplugins = true
  vim.opt.rtp:prepend(vim.env.NVIM_SETUP_ROOT)
  vim.opt.packpath:prepend(vim.env.NVIM_SETUP_ROOT)
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.env.NVIM_SETUP_ROOT .. '/lazy-lock.json'), '\n'))
  local lazy_path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if vim.fn.isdirectory(lazy_path) == 0 then
    vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--no-checkout',
      'https://github.com/folke/lazy.nvim.git', lazy_path })
    assert(vim.v.shell_error == 0, 'Failed to download lazy.nvim')
  end
  vim.fn.system({ 'git', '-C', lazy_path, 'fetch', 'origin', lock['lazy.nvim'].commit })
  assert(vim.v.shell_error == 0, 'Failed to fetch pinned lazy.nvim')
  vim.fn.system({ 'git', '-C', lazy_path, 'checkout', '--detach', lock['lazy.nvim'].commit })
  assert(vim.v.shell_error == 0, 'Failed to restore pinned lazy.nvim')
  require('plugins')
  require('lazy').restore({ wait = true })
  local plugins = require('lazy.core.config').plugins
  for name, pinned in pairs(lock) do
    local plugin = assert(plugins[name], 'Missing plugin specification: ' .. name)
    local head = vim.fn.system({ 'git', '-C', plugin.dir, 'rev-parse', 'HEAD' }):gsub('%s+$', '')
    assert(head == pinned.commit, 'Plugin restore failed: ' .. name)
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:has_errors(), 'Plugin task failed: ' .. name)
    end
  end
  local registry = require('mason-registry')
  local ready, refreshed = false, false
  registry.refresh(function(success) refreshed = success; ready = true end)
  assert(vim.wait(120000, function() return ready end, 100), 'Mason registry refresh timed out')
  assert(refreshed, 'Mason registry refresh failed')
  local names = { 'prettier', 'stylua', 'ruff', 'shfmt', 'google-java-format',
    'php-cs-fixer', 'rubyfmt', 'sql-formatter', 'taplo', 'typescript-language-server' }
  local remaining, failures = 0, {}
  for _, name in ipairs(names) do
    local pkg = registry.get_package(name)
    if not pkg:is_installed() then
      remaining = remaining + 1
      pkg:install({}, function(success)
        if not success then table.insert(failures, name) end
        remaining = remaining - 1
      end)
    end
  end
  assert(vim.wait(1200000, function() return remaining == 0 end, 100), 'Mason installation timed out')
  assert(#failures == 0, 'Mason installation failed: ' .. table.concat(failures, ', '))
  for _, name in ipairs(names) do
    assert(registry.get_package(name):is_installed(), 'Missing Mason package: ' .. name)
  end
  local parsers = require('nvim-treesitter.configs').get_ensure_installed_parsers()
  vim.cmd('TSInstallSync! ' .. table.concat(parsers, ' '))
  for _, language in ipairs(parsers) do
    assert(pcall(vim.treesitter.language.add, language), 'Missing Treesitter parser: ' .. language)
  end
  print('Pinned plugins, Mason tools, and Treesitter parsers are ready.')
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
