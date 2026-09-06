-- Run with the real config, activity tracking disabled, and no user file open.
local function check()
  local function keys(sequence)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
  end
  for _, mode in ipairs({ "n", "i", "x" }) do
    assert(vim.fn.maparg("<A-f>", mode) ~= "", "Missing format shortcut")
    assert(vim.fn.maparg("<C-r>", mode) ~= "", "Missing delete-word shortcut")
  end
  for _, key in ipairs({ "c", "C", "d", "D" }) do
    assert(vim.fn.maparg(key, "s") == "", "Visual mapping leaked into Select mode: " .. key)
  end
  assert(vim.fn.maparg("n", "n") == "gt", "Missing next-tab shortcut")
  assert(vim.fn.maparg("<C-w>", "n", false, true).nowait == 1, "Close shortcut waits for a prefix")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one two three" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  keys("<C-r>")
  assert(vim.api.nvim_get_current_line() == "one  three", "Word deletion failed")
  vim.bo.modified = false

  vim.cmd("vsplit")
  keys("<C-w>")
  assert(#vim.api.nvim_tabpage_list_wins(0) == 1, "Split close failed")
  vim.cmd("tabnew")
  keys("<C-w>")
  assert(#vim.api.nvim_list_tabpages() == 1, "Single-window tab close failed")

  local terminal = require("core.terminal")
  for _, half in ipairs({ "shell", "list" }) do
    terminal.open()
    local buf = vim.api.nvim_get_current_buf()
    if half == "list" then terminal.focus_list() end
    keys("<C-w>")
    assert(vim.wait(1000, function()
      return #vim.api.nvim_tabpage_list_wins(0) == 1
    end, 10), "Orphan terminal panel after closing " .. half)
    terminal.toggle()
    assert(vim.api.nvim_get_current_buf() == buf, "Toggle failed to restore retained shell")
    terminal.delete()
  end
  print("PASS: editor shortcuts, Select-mode isolation, split/tab close, terminal panel cleanup")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  print(err)
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
