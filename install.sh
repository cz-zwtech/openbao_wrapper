#!/usr/bin/env bash
# Install bao-run to ~/.local/bin.
#   ./install.sh            symlink (default)
#   ./install.sh --copy     copy instead of symlink
#   ./install.sh --force    replace an existing, different bao-run
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bao-run"
dest="${BAO_RUN_BIN:-$HOME/.local/bin}"
target="$dest/bao-run"

mode="symlink"; force=0
for a in "$@"; do
  case "$a" in
    --copy)  mode="copy" ;;
    --force) force=1 ;;
    *) echo "install.sh: unknown option '$a'" >&2; exit 64 ;;
  esac
done

mkdir -p "$dest"

# Don't silently clobber a DIFFERENT existing bao-run. A pre-existing wrapper may
# carry different defaults (e.g. a baked BAO_SECRET_PATH); replacing it without
# notice can break callers that relied on that default. Require --force.
if [[ -e "$target" || -L "$target" ]]; then
  existing="$(readlink -f "$target" 2>/dev/null || echo "$target")"
  ours="$(readlink -f "$src" 2>/dev/null || echo "$src")"
  if [[ "$existing" != "$ours" && $force -eq 0 ]]; then
    echo "bao-run: $target already exists and is not this repo's copy." >&2
    echo "  Replacing it may change defaults (e.g. BAO_SECRET_PATH=secret/app)." >&2
    echo "  Re-run with --force to replace it; set BAO_SECRET_PATH if callers relied on the old default." >&2
    exit 1
  fi
fi

if [[ "$mode" == "copy" ]]; then
  install -m 0755 "$src" "$target"
  echo "bao-run: copied → $target"
else
  ln -sf "$src" "$target"
  echo "bao-run: symlinked → $target"
fi

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "bao-run: note — $dest is not on your PATH; add it to use 'bao-run' directly." ;;
esac
