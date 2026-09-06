-- Manage formatter executables with :Mason.
-- Install on a fresh machine:
-- :MasonInstall prettier stylua ruff shfmt google-java-format php-cs-fixer rubyfmt sql-formatter taplo
-- Language servers: :MasonInstall typescript-language-server
-- Install clang-format with: uv tool install clang-format
-- Go and Rust formatting use gofmt and rustfmt from their language toolchains.
require("mason").setup({})
