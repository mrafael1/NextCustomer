#!/bin/sh
# Rebuilds the screens_rack_* mock-ups from screens_src/base_b2_mirrored.html and captures each at 1920x1080
# (1280x720 at 1.5x) in headless Chrome. CHROME picks the browser; the profile is a throwaway folder under TMPDIR.
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/chrome56_rack"
python "$HERE/gen_rack.py" || exit 1
cd "$MOCKUPS" || exit 1
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
for f in screens_rack_a screens_rack_a_start screens_rack_a_scan screens_rack_b screens_rack_b_start screens_rack_b_scan; do
  in=$(to_native "$(realpath "$f.html")"); out=$(to_native "$(realpath -m "${f}_1920x1080.png")")
  timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
    --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
    --screenshot="$out" "file:///$in" >/dev/null 2>&1
  test -s "${f}_1920x1080.png" && echo "wrote ${f}_1920x1080.png" || { echo "capture failed: $f"; exit 1; }
done
rm -rf "$prof"
