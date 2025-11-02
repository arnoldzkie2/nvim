require("telescope").setup({
  defaults = {
    mappings = {
      i = {
        -- Press Enter to open file in new tab
        ["<cr>"] = function(bufnr)
          require("telescope.actions.set").edit(bufnr, "tab drop")
        end
      },
      n = {
        -- Also work in normal mode inside Telescope
        ["<cr>"] = function(bufnr)
          require("telescope.actions.set").edit(bufnr, "tab drop")
        end
      }
    }
  }
})
