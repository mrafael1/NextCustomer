#!/bin/sh
# usage: sh cap.sh <page.html> "<query>" <out.png>: a 1920x1080 capture (1280x720 at 1.5x) in headless Chrome.
# The query string (e.g. "draw=5&t=1.6&cap=1") freezes a state. CHROME picks the browser; the profile is a throwaway
# folder under TMPDIR, removed afterwards. One capture at a time.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/nc_chrome_capsule63"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$(realpath "$1")")
out=$(to_native "$(realpath -m "$3")")
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
  --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
  --screenshot="$out" "file:///$in?$2" >/dev/null 2>&1
rm -rf "$prof"
test -s "$3" && echo "wrote $3" || { echo "capture failed"; exit 1; }
