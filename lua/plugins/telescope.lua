local function open_split(command)
  return function(prompt_bufnr)
    require("telescope.actions.set").edit(prompt_bufnr, command)
  end
end

require("telescope").setup({
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
  },
  defaults = {
    -- Bound preview work when scrolling across large/minified files.
    preview = {
      filesize_limit = 0.5,
      highlight_limit = 0.1,
      treesitter = false,
    },
    mappings = {
      i = {
        ["<A-w>"] = open_split("leftabove new"),
        ["<A-a>"] = open_split("leftabove vnew"),
        ["<A-s>"] = open_split("rightbelow new"),
        ["<A-d>"] = open_split("rightbelow vnew"),
        -- GNOME Terminal sends Ctrl+Enter as Enter; Alt+Enter is distinct.
        ["<M-CR>"] = require("telescope.actions").select_vertical,
        ["<C-CR>"] = require("telescope.actions").select_vertical,
        -- Press Enter to open file in new tab
        ["<cr>"] = function(bufnr)
          require("telescope.actions.set").edit(bufnr, "tabedit")
        end
      },
      n = {
        ["<A-w>"] = open_split("leftabove new"),
        ["<A-a>"] = open_split("leftabove vnew"),
        ["<A-s>"] = open_split("rightbelow new"),
        ["<A-d>"] = open_split("rightbelow vnew"),
        -- GNOME Terminal sends Ctrl+Enter as Enter; Alt+Enter is distinct.
        ["<M-CR>"] = require("telescope.actions").select_vertical,
        ["<C-CR>"] = require("telescope.actions").select_vertical,
        -- Also work in normal mode inside Telescope
        ["<cr>"] = function(bufnr)
          require("telescope.actions.set").edit(bufnr, "tabedit")
        end
      }
    }
  }
})

require("telescope").load_extension("fzf")

vim.keymap.set({ "n", "i" }, "<C-e>", "<cmd>Telescope find_files<CR>", {
  desc = "Find files",
})
-- Ctrl+D belongs to multiple-cursor selection.
vim.keymap.set("n", "<leader>b", "<cmd>Telescope buffers<CR>", {
  desc = "Search open buffers",
})
