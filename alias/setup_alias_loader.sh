#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null || { echo 'Missing jq; install it first.' >&2; exit 1; }
ALIAS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
JSON="$ALIAS_DIR/aliases.json"
# Fail before editing shell configuration if the alias file is invalid.
jq -e 'type == "object" and all(.[]; type == "string")' "$JSON" >/dev/null

# Keep the existing loader on machines where it was already registered.
if ! grep -q 'load_json_aliases' "$HOME/.bashrc" 2>/dev/null; then
  {
    printf '\nload_json_aliases() {\n'
    printf '    local alias_file=%q\n' "$JSON"
    printf '%s\n' '    if command -v jq >/dev/null && [ -f "$alias_file" ]; then'
    printf '%s\n' '        eval "$(jq -r '\''to_entries[] | "alias \(.key)=\(.value | @sh)"'\'' "$alias_file")"'
    printf '%s\n' '    fi' '}' 'load_json_aliases'
  } >> "$HOME/.bashrc"
  echo 'Added JSON alias loader to ~/.bashrc.'
else
  echo 'JSON alias loader already registered in ~/.bashrc.'
fi
# Do not source .bashrc here: a child process cannot change its parent shell.
echo 'Open a new Bash terminal or run: source ~/.bashrc'
