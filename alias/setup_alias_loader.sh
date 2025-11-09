#!/bin/bash
LOADER='load_json_aliases() {
    if [ -f ~/.config/nvim/alias/aliases.json ]; then
        eval "$(jq -r '"'"'to_entries[] | "alias \(.key)=\(.value | @sh)"'"'"' ~/.config/nvim/alias/aliases.json 2>/dev/null || echo "")"
    fi
}
load_json_aliases'
if ! grep -q "load_json_aliases" ~/.bashrc; then
    echo "$LOADER" >> ~/.bashrc
    echo "✓ Added JSON alias loader to .bashrc"
fi
source ~/.bashrc
echo "✓ Aliases loaded"
