#!/bin/sh
# usage: sh docs/art/mockups/screens_src/gen_kiosk/cap.sh <page.html>...: writes <page>_1920x1080.png (1280x720 at 1.5x, headless Chrome).
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/chrome56_kiosk"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
for page in "$@"; do
  png="${page%.html}_1920x1080.png"
  in=$(to_native "$(realpath "$page")"); out=$(to_native "$(realpath -m "$png")")
  timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
    --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
    --screenshot="$out" "file:///$in" >/dev/null 2>&1
  test -s "$png" && echo "wrote $png" || echo "capture failed: $page"
done
rm -rf "$prof"
