require("nvim-tree").setup ({
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)

    local function open_and_keep_focus()
      api.node.open.no_window_picker()
      api.tree.focus()
    end
    for _, key in ipairs({ "<CR>", "s", "<2-LeftMouse>" }) do
      vim.keymap.set("n", key, open_and_keep_focus, {
        buffer = bufnr,
        silent = true,
        desc = "Open file or toggle folder; stay in tree",
      })
    end

    vim.keymap.set("n", "o", api.node.open.no_window_picker, {
      buffer = bufnr,
      silent = true,
      desc = "Open file and focus editor",
    })

    vim.keymap.set("n", "i", function()
      local windows = { vim.fn.win_getid(vim.fn.winnr("#")) }
      vim.list_extend(windows, vim.api.nvim_tabpage_list_wins(0))
      for _, win in ipairs(windows) do
        if vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          local opts = vim.bo[buf]
          if opts.buftype == "" and opts.modifiable and vim.api.nvim_win_get_config(win).relative == "" then
            vim.api.nvim_set_current_win(win)
            vim.cmd.startinsert()
            return
          end
        end
      end
      vim.notify("No editing window available in this tab", vim.log.levels.INFO)
    end, { buffer = bufnr, silent = true, desc = "Return to file and insert" })
  end,
  view = {
    width = 30,
    side = "right",
  },
  tab = {
    sync = {
      open = true,
      close = true,
    },
  },
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    show_on_open_dirs = true,
    severity = {
      min = vim.diagnostic.severity.WARN,
      max = vim.diagnostic.severity.ERROR,
    },
    icons = {
      error = "E",
      warning = "W",
      info = "I",
      hint = "H",
    },
  },
  renderer = {
    highlight_diagnostics = "name",
    icons = {
      diagnostics_placement = "after",
      web_devicons = {
        file = { enable = true, color = true },
      },
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
      },
      glyphs = {
        folder = {
          default = "",
          open = "",
          empty = "",
          empty_open = "",
        },
      },
    },
  },
  filters = {
    dotfiles=true
  }
})

vim.keymap.set({ "n", "i" }, "<C-f>", "<Esc><cmd>NvimTreeToggle<CR>", {
  desc = "Toggle file tree",
})
