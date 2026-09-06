-- ~/.config/nvim/init.lua

-- Load core settings
require("core.options")
require("core.keymaps")
require("core.terminal").setup()
require("core.cmd")
require("core.diagnostics")

-- Load plugins
require("plugins")
