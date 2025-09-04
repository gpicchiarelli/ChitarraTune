#!/usr/bin/env bash
set -euo pipefail

SRC=${1:-"chitarratune.png"}

if [[ ! -f "$SRC" ]]; then
  echo "Source image not found: $SRC" >&2
  exit 1
fi

out_dirs=(
  "ChitarraTune.xcassets/AppIcon.appiconset"
  "Apps/Shared/Assets.xcassets/AppIcon.appiconset"
)

for OUT in "${out_dirs[@]}"; do
  if [[ -d "$OUT" ]]; then
    echo "Generating icons into $OUT"
    sips -Z 16   "$SRC" --out "$OUT/AppIcon-16.png" >/dev/null
    sips -Z 32   "$SRC" --out "$OUT/AppIcon-16@2x.png" >/dev/null
    sips -Z 32   "$SRC" --out "$OUT/AppIcon-32.png" >/dev/null
    sips -Z 64   "$SRC" --out "$OUT/AppIcon-32@2x.png" >/dev/null
    sips -Z 128  "$SRC" --out "$OUT/AppIcon-128.png" >/dev/null
    sips -Z 256  "$SRC" --out "$OUT/AppIcon-128@2x.png" >/dev/null
    sips -Z 256  "$SRC" --out "$OUT/AppIcon-256.png" >/dev/null
    sips -Z 512  "$SRC" --out "$OUT/AppIcon-256@2x.png" >/dev/null
    sips -Z 512  "$SRC" --out "$OUT/AppIcon-512.png" >/dev/null
    sips -Z 1024 "$SRC" --out "$OUT/AppIcon-512@2x.png" >/dev/null
  fi
done

echo "Done."

