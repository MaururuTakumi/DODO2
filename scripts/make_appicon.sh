#!/usr/bin/env bash
# make icons — Generate macOS AppIcon set from a 1024px master PNG
#
# Usage:
#   scripts/make_appicon.sh [Design/AppIcon/DODO_icon_1024.png]
#
# Notes:
# - Writes 10 PNGs into Assets.xcassets/AppIcon.appiconset with required names.
# - Recreates Contents.json to match filenames and idiom "mac".
# - Idempotent: safe to re-run; overwrites existing files.
# - If the 1024 master is missing, generates a temporary placeholder (transparent) so builds can proceed.
set -euo pipefail

SRC_DEFAULT="Design/AppIcon/DODO_icon_1024.png"
SRC_INPUT="${1:-$SRC_DEFAULT}"
OUT_DIR="Assets.xcassets/AppIcon.appiconset"

command -v sips >/dev/null 2>&1 || { echo >&2 "error: 'sips' not found (macOS tool required)"; exit 1; }

mkdir -p "$OUT_DIR"

cleanup_tmp() { [[ -n "${TMP_SRC:-}" && -f "${TMP_SRC}" ]] && rm -f "${TMP_SRC}" || true; }
trap cleanup_tmp EXIT

if [[ ! -f "$SRC_INPUT" ]]; then
  echo "warn: source '$SRC_INPUT' not found; generating a transparent placeholder"
  TMP_SRC=$(mktemp -t dodo_appicon_src_XXXX).png
  # 1x1 transparent PNG (base64), then upscale to 1024x1024 as placeholder
  printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+WY0kAAAAASUVORK5CYII=' | base64 --decode > "$TMP_SRC"
  sips -s format png -z 1024 1024 "$TMP_SRC" --out "$TMP_SRC.out.png" >/dev/null
  mv -f "$TMP_SRC.out.png" "$TMP_SRC"
  SRC="$TMP_SRC"
else
  SRC="$SRC_INPUT"
fi

# Map of target outputs: filename width height
read -r -d '' MAP <<'EOF' || true
icon_16.png 16 16
icon_16@2x.png 32 32
icon_32.png 32 32
icon_32@2x.png 64 64
icon_128.png 128 128
icon_128@2x.png 256 256
icon_256.png 256 256
icon_256@2x.png 512 512
icon_512.png 512 512
icon_512@2x.png 1024 1024
EOF

while read -r NAME W H; do
  [[ -z "$NAME" ]] && continue
  echo "generating $NAME (${W}x${H})"
  sips -s format png -z "$H" "$W" "$SRC" --out "$OUT_DIR/$NAME" >/dev/null
done <<< "$MAP"

cat > "$OUT_DIR/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "size": "16x16",  "scale": "1x", "filename": "icon_16.png" },
    { "idiom": "mac", "size": "16x16",  "scale": "2x", "filename": "icon_16@2x.png" },
    { "idiom": "mac", "size": "32x32",  "scale": "1x", "filename": "icon_32.png" },
    { "idiom": "mac", "size": "32x32",  "scale": "2x", "filename": "icon_32@2x.png" },
    { "idiom": "mac", "size": "128x128","scale": "1x", "filename": "icon_128.png" },
    { "idiom": "mac", "size": "128x128","scale": "2x", "filename": "icon_128@2x.png" },
    { "idiom": "mac", "size": "256x256","scale": "1x", "filename": "icon_256.png" },
    { "idiom": "mac", "size": "256x256","scale": "2x", "filename": "icon_256@2x.png" },
    { "idiom": "mac", "size": "512x512","scale": "1x", "filename": "icon_512.png" },
    { "idiom": "mac", "size": "512x512","scale": "2x", "filename": "icon_512@2x.png" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
JSON

echo "done: AppIcon written to $OUT_DIR"
