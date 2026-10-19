#!/bin/sh
# usage: sh cap.sh <page.html> <out.png>: a 1920x1080 capture (1280x720 at 1.5x) in headless Chrome.
# CHROME picks the browser; the profile is a throwaway folder under TMPDIR.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/next_customer_chrome_h1"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$(realpath "$1")")
out=$(to_native "$(realpath -m "$2")")
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
  --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
  --screenshot="$out" "file:///$in" >/dev/null 2>&1
test -s "$2" && echo "wrote $2" || { echo "capture failed"; exit 1; }
