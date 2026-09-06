-- Save each buffer after typing has paused for 500 ms.
local group = vim.api.nvim_create_augroup("AutoSave", { clear = true })
local pending = {}

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
  group = group,
  callback = function(event)
    local buf = event.buf
    local request = {}
    pending[buf] = request

    vim.defer_fn(function()
      if pending[buf] ~= request then
        return
      end
      pending[buf] = nil

      if not vim.api.nvim_buf_is_loaded(buf) then
        return
      end

      local opts = vim.bo[buf]
      local name = vim.api.nvim_buf_get_name(buf)
      if opts.buftype ~= "" or not opts.modifiable or opts.readonly or not opts.modified or name == "" then
        return
      end

      local writable = vim.fn.filewritable(name) == 1
      if vim.fn.getftype(name) == "" then
        writable = vim.fn.filewritable(vim.fn.fnamemodify(name, ":h")) == 2
      end
      if not writable then
        vim.notify("Autosave skipped: file is not writable: " .. name, vim.log.levels.WARN)
        return
      end

      local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
        vim.cmd("silent update")
      end)
      if not ok then
        vim.notify("Autosave failed for " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
      end
    end, 500)
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(event)
    pending[event.buf] = nil
  end,
})
