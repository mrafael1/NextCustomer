#!/bin/sh
# usage: sh cap.sh <page.html> <out.png> [query] [css height]: a capture at 1.5x in headless Chrome
# (1280 x height CSS px, default 720), e.g. sh cap.sh page.html out.png "at=6.5". Round 5 (#86).
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/chrome86v5"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$(realpath "$1")")
out=$(to_native "$(realpath -m "$2")")
query=${3:+?$3}
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
  --window-size=1280,${4:-720} --virtual-time-budget=3000 --allow-file-access-from-files \
  --user-data-dir="$(to_native "$prof")" --screenshot="$out" "file:///$in$query" >/dev/null 2>&1
test -s "$2" && echo "wrote $2" || { echo "capture failed"; exit 1; }
