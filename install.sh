#!/usr/bin/env bash
# Install bao-run to ~/.local/bin (symlink by default; pass --copy to copy).
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bao-run"
dest="${BAO_RUN_BIN:-$HOME/.local/bin}"
mkdir -p "$dest"

if [[ "${1:-}" == "--copy" ]]; then
  install -m 0755 "$src" "$dest/bao-run"
  echo "bao-run: copied → $dest/bao-run"
else
  ln -sf "$src" "$dest/bao-run"
  echo "bao-run: symlinked → $dest/bao-run"
fi

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "bao-run: note — $dest is not on your PATH; add it to use 'bao-run' directly." ;;
esac
