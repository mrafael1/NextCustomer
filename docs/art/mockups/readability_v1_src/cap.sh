#!/bin/sh
# usage: sh cap.sh <out.png> "<query>" [width] [height]: one still of ../readability_v1.html in headless Chrome,
# e.g. sh cap.sh ../readability_v1_monitor_B.png "solo=monitor&v=B&at=2.6". shot=1 is added.
# Run build.py first (the page embeds the game's fonts). CHROME picks the browser.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
here=$(cd "$(dirname "$0")" && pwd)
prof="${TMPDIR:-/tmp}/next_customer_chrome_readability"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$here/../readability_v1.html")
out=$(to_native "$(realpath -m "$1")")
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=${3:-1280},${4:-720} --virtual-time-budget=6000 --allow-file-access-from-files \
  --user-data-dir="$(to_native "$prof")" --screenshot="$out" "file:///$in?shot=1&$2" >/dev/null 2>&1
test -s "$1" && echo "wrote $1" || { echo "capture failed: $1"; exit 1; }
