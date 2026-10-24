#!/bin/sh
# usage: sh cap.sh <out.png> <query> [height] [width]: a 1280x720 capture of cart_reveal_v1.html in headless Chrome,
# e.g. sh cap.sh ../cart_reveal_v1_A_end.png "v=A&at=3.2&solo=1". CHROME picks the browser.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
here=$(cd "$(dirname "$0")" && pwd)
prof="${TMPDIR:-/tmp}/next_customer_chrome_cart_reveal"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$here/../cart_reveal_v1.html")
out=$(to_native "$(realpath -m "$1")")
timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=${4:-1280},${3:-720} --virtual-time-budget=4000 --allow-file-access-from-files \
  --user-data-dir="$(to_native "$prof")" --screenshot="$out" "file:///$in?$2" >/dev/null 2>&1
test -s "$1" && echo "wrote $1" || { echo "capture failed"; exit 1; }
