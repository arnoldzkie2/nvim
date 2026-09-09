#!/usr/bin/env bash
# Install the official Neovim Linux release. Does not modify your configuration.
set -euo pipefail

VERSION=0.11.4
if [[ "$(uname -s)" != Linux ]]; then
  echo 'This installer supports Linux only.' >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo 'Unsupported architecture; use x86_64 or ARM64.' >&2; exit 1 ;;
esac

SUDO=()
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null || { echo 'Run as root or install sudo.' >&2; exit 1; }
  SUDO=(sudo)
fi

DEST="/opt/nvim-linux-$ARCH"
LINK=/usr/local/bin/nvim
if [[ -e "$LINK" && ! -L "$LINK" ]]; then
  echo "$LINK is not a symlink. Move it aside before installing." >&2
  exit 1
fi

# Build tools support plugin installation on first launch; ripgrep powers search.
if command -v apt-get >/dev/null; then
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y curl ca-certificates tar git build-essential ripgrep
fi
for tool in curl tar git make cc; do
  command -v "$tool" >/dev/null || { echo "Install $tool and rerun this script." >&2; exit 1; }
done

TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
ARCHIVE="nvim-linux-$ARCH.tar.gz"
curl --fail --location --retry 3 --output "$TMP/$ARCHIVE" \
  "https://github.com/neovim/neovim/releases/download/v$VERSION/$ARCHIVE"
tar -xzf "$TMP/$ARCHIVE" -C "$TMP"
# Check compatibility before replacing an existing installation.
"$TMP/nvim-linux-$ARCH/bin/nvim" --version

"${SUDO[@]}" mkdir -p /opt /usr/local/bin
if [[ -e "$DEST" || -L "$DEST" ]]; then
  BACKUP="${DEST}.backup.$(date +%s).$$"
  "${SUDO[@]}" mv -- "$DEST" "$BACKUP"
  echo "Previous installation saved to $BACKUP"
fi
"${SUDO[@]}" mv -- "$TMP/nvim-linux-$ARCH" "$DEST"
"${SUDO[@]}" chown -R root:root "$DEST"
"${SUDO[@]}" ln -sfn -- "$DEST/bin/nvim" "$LINK"
"$LINK" --version

printf '\nInstalled Neovim %s. Your configuration was not changed.\n' "$VERSION"
echo 'Run these in your terminal:'
echo '  hash -r'
echo '  /usr/local/bin/nvim'
echo 'Inside Neovim, run :Lazy restore to restore the pinned plugins.'
echo 'If plain nvim still uses Snap, ensure /usr/local/bin comes before /snap/bin in PATH.'
