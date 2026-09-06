-- Advertise Blink's completion support, including resolved import edits.
vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

-- Preserve lspconfig's monorepo root detection and Deno exclusions.
local project_root = vim.lsp.config.ts_ls.root_dir
local native_bins = {}
local function native_compiler(root)
  local manifest = root .. "/node_modules/typescript/package.json"
  local ok, package = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(manifest), "\n"))
  end)
  local major = ok and type(package) == "table" and tonumber((package.version or ""):match("^(%d+)"))
  local bin = root .. "/node_modules/.bin/tsc"
  if major and major >= 7 and vim.fn.executable(bin) == 1 then
    return bin
  end
end

vim.lsp.config("tsc", {
  root_dir = function(bufnr, on_dir)
    project_root(bufnr, function(root)
      local bin = native_compiler(root)
      if bin then
        native_bins[root] = bin
        on_dir(root)
      end
    end)
  end,
  cmd = function(dispatchers, config)
    return vim.lsp.rpc.start({ assert(native_bins[config.root_dir]), "--lsp", "--stdio" }, dispatchers)
  end,
})

vim.lsp.config("ts_ls", {
  root_dir = function(bufnr, on_dir)
    project_root(bufnr, function(root)
      if not native_compiler(root) then
        on_dir(root)
      end
    end)
  end,
  init_options = {
    preferences = {
      includeCompletionsForModuleExports = true,
      includeCompletionsForImportStatements = true,
      includeCompletionsWithInsertText = true,
      includeAutomaticOptionalChainCompletions = true,
    },
  },
})

vim.lsp.enable({ "tsc", "ts_ls" })
