-- Richer accents on a soft dark background, without pure-white text.
require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = false,
  dim_inactive = { enabled = false },
  color_overrides = {
    mocha = {
      base = "#171c28",
      mantle = "#131722",
      crust = "#10131c",
      text = "#dce3ed",
      subtext1 = "#bdc8db",
      subtext0 = "#a5b2ca",
      overlay2 = "#94a3bd",
      overlay1 = "#8290a6",
      overlay0 = "#74829a",
      surface2 = "#48566f",
      surface1 = "#35435c",
      surface0 = "#252e40",
      blue = "#6caeff",
      sapphire = "#59b9ed",
      sky = "#77cfe8",
      teal = "#65cfbc",
      green = "#8bd49c",
      yellow = "#e8c778",
      peach = "#efa66c",
      red = "#ed7c90",
      maroon = "#dc8c9b",
      mauve = "#bb9af7",
      pink = "#df9ed0",
      lavender = "#a3b4ff",
    },
  },
  custom_highlights = function(colors)
    return {
      Comment = { fg = colors.overlay1 },
      LineNr = { fg = colors.overlay0 },
      CursorLineNr = { fg = colors.peach, bold = true },
      CursorLine = { bg = "#202838" },
      Visual = { bg = "#354769" },
      WinSeparator = { fg = colors.surface2 },
    }
  end,
})
vim.cmd.colorscheme("catppuccin")
