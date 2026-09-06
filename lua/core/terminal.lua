local M = {}
local sessions = {}
local panels = {}
local next_id = 0
local last_active = {}
local refresh

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function input_in(win)
  vim.schedule(function()
    if valid(win) and vim.api.nvim_get_current_win() == win then
      vim.cmd.startinsert()
    end
  end)
end

-- Reconcile sessions with Neovim: tabs and terminal buffers may be closed
-- outside this panel (tabclose, bdelete, or Enter after a shell exits).
local function prune()
  for tab, p in pairs(panels) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      panels[tab] = nil
      last_active[tab] = nil
      if vim.api.nvim_buf_is_valid(p.list_buf) then
        vim.api.nvim_buf_delete(p.list_buf, { force = true })
      end
    elseif p.term_win and p.list_win and (not valid(p.term_win) or not valid(p.list_win)) then
      -- Closing either half of the panel should hide the remaining half too.
      -- Keep the shell session alive for the next toggle.
      M.close(tab, false)
    end
  end

  local live = {}
  for index = #sessions, 1, -1 do
    local session = sessions[index]
    if vim.api.nvim_buf_is_loaded(session.buf) and vim.bo[session.buf].buftype == "terminal" then
      live[session.id] = session
    else
      table.remove(sessions, index)
      if session.job and session.job > 0 then
        pcall(vim.fn.jobstop, session.job)
      end
    end
  end
  local fallback = sessions[#sessions]
  for tab, id in pairs(last_active) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      last_active[tab] = nil
    elseif not live[id] then
      last_active[tab] = fallback and fallback.id
    end
  end
  for _, tab in ipairs(vim.tbl_keys(panels)) do
    local p = panels[tab]
    if not live[p.active] then
      if fallback then
        p.active = fallback.id
        last_active[tab] = fallback.id
        if valid(p.term_win) then
          vim.api.nvim_win_set_buf(p.term_win, fallback.buf)
        end
      else
        M.close(tab)
      end
    end
  end
  refresh()
end

local function panel()
  return panels[vim.api.nvim_get_current_tabpage()]
end

refresh = function()
  for _, p in pairs(panels) do
    if vim.api.nvim_buf_is_valid(p.list_buf) then
      local lines = { "+ New terminal (n)", "Enter: switch  d: delete" }
      for _, session in ipairs(sessions) do
        local marker = p.active == session.id and "> " or "  "
        local status = session.exited and " [exited]" or ""
        lines[#lines + 1] = marker .. session.id .. ": " .. session.name .. status
      end
      vim.bo[p.list_buf].modifiable = true
      vim.api.nvim_buf_set_lines(p.list_buf, 0, -1, false, lines)
      vim.bo[p.list_buf].modifiable = false
    end
  end
end

function M.select(id)
  local p = panel()
  if not p or not valid(p.term_win) then
    return
  end
  for _, session in ipairs(sessions) do
    if session.id == id and vim.api.nvim_buf_is_valid(session.buf) then
      p.active = id
      last_active[vim.api.nvim_get_current_tabpage()] = id
      vim.api.nvim_win_set_buf(p.term_win, session.buf)
      vim.api.nvim_set_current_win(p.term_win)
      refresh()
      if not session.exited then
        input_in(p.term_win)
      end
      return
    end
  end
end

function M.new()
  local p = panel()
  if not p or not valid(p.term_win) then
    M.open(true)
    return
  end
  local cwd = vim.fn.getcwd()
  next_id = next_id + 1
  local session = {
    id = next_id,
    buf = vim.api.nvim_create_buf(false, true),
    name = vim.fn.fnamemodify(vim.o.shell, ":t"),
  }
  vim.bo[session.buf].bufhidden = "hide"
  -- Keep Alt+D navigation in editing buffers; cycle only inside this panel.
  for _, mode in ipairs({ "n", "x", "t" }) do
    local leave = mode == "t" and "<C-\\><C-n>" or (mode == "x" and "<Esc>" or "")
    vim.keymap.set(mode, "<A-d>", leave .. "<cmd>lua require('core.terminal').next()<CR>", {
      buffer = session.buf,
      desc = "Next terminal",
    })
  end
  vim.api.nvim_win_set_buf(p.term_win, session.buf)
  vim.api.nvim_set_current_win(p.term_win)
  session.job = vim.fn.jobstart(vim.o.shell, {
    term = true,
    cwd = cwd,
    on_exit = function()
      vim.schedule(function()
        session.exited = true
        refresh()
      end)
    end,
  })
  sessions[#sessions + 1] = session
  M.select(session.id)
end

function M.close(tab, resume_insert)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local current_tab = tab == vim.api.nvim_get_current_tabpage()
  local p = panels[tab]
  if not p then
    return
  end
  if not vim.api.nvim_tabpage_is_valid(tab) then
    panels[tab] = nil
    last_active[tab] = nil
    if vim.api.nvim_buf_is_valid(p.list_buf) then
      vim.api.nvim_buf_delete(p.list_buf, { force = true })
    end
    return
  end
  if current_tab then vim.cmd.stopinsert() end
  -- Keep at least one editing window when users have closed the others.
  local other_window = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if win ~= p.list_win and win ~= p.term_win then
      other_window = true
    end
  end
  if not other_window then
    vim.api.nvim_win_call(valid(p.term_win) and p.term_win or p.list_win, function()
      vim.cmd("topleft new")
      p.return_win = vim.api.nvim_get_current_win()
    end)
  end
  for _, win in ipairs({ p.list_win, p.term_win }) do
    if valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  if current_tab then
    if valid(p.return_win) then
      vim.api.nvim_set_current_win(p.return_win)
    end
    if vim.bo.buftype == "" and vim.bo.modifiable and resume_insert ~= false then
      input_in(vim.api.nvim_get_current_win())
    end
  end
  if vim.api.nvim_buf_is_valid(p.list_buf) then
    vim.api.nvim_buf_delete(p.list_buf, { force = true })
  end
  panels[tab] = nil
end

function M.open(create_new)
  prune()
  local p = panel()
  if p and valid(p.term_win) and valid(p.list_win) then
    M.select(p.active)
    return
  elseif p then
    M.close(nil, false)
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local return_win = vim.api.nvim_get_current_win()
  if vim.bo.buftype ~= "" then
    local candidates = { vim.fn.win_getid(vim.fn.winnr("#")) }
    vim.list_extend(candidates, vim.api.nvim_tabpage_list_wins(0))
    for _, win in ipairs(candidates) do
      if valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
        return_win = win
        break
      end
    end
  end
  p = { return_win = return_win }
  panels[tab] = p
  local height = math.max(3, math.min(12, math.floor(vim.o.lines / 3)))
  vim.cmd("botright " .. height .. "split")
  p.term_win = vim.api.nvim_get_current_win()
  vim.wo[p.term_win].winfixheight = true
  vim.cmd("belowright 24vsplit")
  p.list_win = vim.api.nvim_get_current_win()
  p.list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[p.list_buf].bufhidden = "hide"
  vim.bo[p.list_buf].filetype = "terminal_list"
  vim.api.nvim_win_set_buf(p.list_win, p.list_buf)
  for option, value in pairs({
    number = false,
    relativenumber = false,
    signcolumn = "no",
    wrap = false,
    cursorline = true,
    winfixwidth = true,
    winfixheight = true,
    winbar = " Terminals",
  }) do
    vim.wo[p.list_win][option] = value
  end
  local function choose()
    local row = vim.api.nvim_win_get_cursor(p.list_win)[1]
    if row == 1 then
      M.new()
    elseif sessions[row - 2] then
      M.select(sessions[row - 2].id)
    end
  end
  local function map(key, callback, desc)
    vim.keymap.set("n", key, callback, { buffer = p.list_buf, silent = true, desc = desc })
  end
  map("n", M.new, "New terminal")
  map("<A-d>", M.next, "Next terminal")
  map("<CR>", choose, "Switch terminal")
  map("<2-LeftMouse>", choose, "Switch terminal")
  map("q", M.close, "Hide terminal panel")
  map("d", function()
    local row = vim.api.nvim_win_get_cursor(p.list_win)[1]
    if sessions[row - 2] then
      M.delete(sessions[row - 2].id)
    end
  end, "Delete selected terminal")
  refresh()
  if create_new or #sessions == 0 then
    M.new()
  else
    M.select(last_active[tab] or sessions[#sessions].id)
  end
end

function M.next()
  prune()
  local p = panel()
  if not p or not valid(p.term_win) then
    M.open()
    return
  end
  for index, session in ipairs(sessions) do
    if session.id == p.active then
      M.select(sessions[index % #sessions + 1].id)
      return
    end
  end
end

function M.delete(id)
  prune()
  local p = panel()
  if not id and p and vim.api.nvim_get_current_buf() == p.list_buf then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local selected = sessions[row - 2]
    if not selected then return end
    id = selected.id
  end
  id = id or (p and p.active)
  for index, session in ipairs(sessions) do
    if session.id == id then
      table.remove(sessions, index)
      local replacement = sessions[math.min(index, #sessions)]
      for tab, active in pairs(last_active) do
        if active == id then last_active[tab] = replacement and replacement.id end
      end
      local tabs = vim.tbl_keys(panels)
      for _, tab in ipairs(tabs) do
        local other = panels[tab]
        if not replacement then
          M.close(tab)
        elseif other.active == id then
          other.active = replacement.id
          if valid(other.term_win) then
            vim.api.nvim_win_set_buf(other.term_win, replacement.buf)
          end
        end
      end
      if session.job and session.job > 0 then
        pcall(vim.fn.jobstop, session.job)
      end
      if vim.api.nvim_buf_is_valid(session.buf) then
        vim.api.nvim_buf_delete(session.buf, { force = true })
      end
      refresh()
      if replacement and panel() then M.select(panel().active) end
      return
    end
  end
end

function M.toggle()
  prune()
  local p = panel()
  if p and (valid(p.term_win) or valid(p.list_win)) then
    M.close()
  else
    M.open()
  end
end

function M.focus_list()
  local p = panel()
  if not p or not valid(p.list_win) then
    M.open()
    p = panel()
  end
  vim.cmd.stopinsert()
  vim.api.nvim_set_current_win(p.list_win)
end

local group = vim.api.nvim_create_augroup("TerminalPanelLifecycle", { clear = true })
vim.api.nvim_create_autocmd({ "WinClosed", "TabClosed", "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function()
    -- Buffer events run before deletion finishes and may hold a text lock.
    vim.schedule(prune)
  end,
})

-- Keep terminal shortcuts with the panel implementation.
function M.setup()
  local shortcuts = {
    { "<C-j>", "toggle", "Toggle terminal panel" },
    { "<A-n>", "new", "New terminal" },
    { "<A-x>", "delete", "Delete selected terminal" },
    { "<A-t>", "focus_list", "Focus terminal list" },
  }
  for _, mode in ipairs({ "n", "i", "x", "t" }) do
    local leave = mode == "t" and "<C-\\><C-n>" or (mode == "x" and "<Esc>" or "")
    for _, shortcut in ipairs(shortcuts) do
      vim.keymap.set(mode, shortcut[1], leave .. "<cmd>lua require('core.terminal')." .. shortcut[2] .. "()<CR>", {
        silent = true,
        desc = shortcut[3],
      })
    end
  end
end

return M
