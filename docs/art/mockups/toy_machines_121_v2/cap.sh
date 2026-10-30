#!/bin/sh
# usage: sh cap.sh <page.html> "<query>" <out.png> [w] [h] [dpr]: one headless Chrome capture (default 1280x720 at 1x).
# The profile is a throwaway folder under TMPDIR, removed afterwards; Chrome is time-limited to 90 s. One capture at a time.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/nc_chrome_toys121v2"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$(realpath "$1")")
out=$(to_native "$(realpath -m "$3")")
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor="${6:-1}" \
  --window-size="${4:-1280},${5:-720}" --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
  --screenshot="$out" "file:///$in?$2" >/dev/null 2>&1
rm -rf "$prof"
test -s "$3" && echo "wrote $3" || { echo "capture failed"; exit 1; }
