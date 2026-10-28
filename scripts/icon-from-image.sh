#!/bin/zsh
# Make assets/AppIcon.icns from a square image, as-is (no padding or effects).
# Usage: scripts/icon-from-image.sh [image.png]   (default: assets/AppIcon-source.png)
set -euo pipefail
cd "${0:A:h}/.."
SRC="${1:-assets/AppIcon-source.png}"
if [[ ! -f "$SRC" ]]; then
    echo "error: no image at '$SRC'. Pass the path to a real PNG, e.g. scripts/icon-from-image.sh ~/Downloads/logo.png" >&2
    exit 1
fi
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for base in 16 32 128 256 512; do
    sips -z $base $base "$SRC" --out "$SET/icon_${base}x${base}.png" >/dev/null
    sips -z $((base * 2)) $((base * 2)) "$SRC" --out "$SET/icon_${base}x${base}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o assets/AppIcon.icns
echo "wrote assets/AppIcon.icns from $SRC"
