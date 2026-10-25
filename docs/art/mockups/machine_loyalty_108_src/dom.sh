#!/bin/sh
# usage: sh dom.sh "<query>": loads ../machine_loyalty_108.html headless and prints the page title (a script error
# is appended to it as "ERROR:...").
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
here=$(cd "$(dirname "$0")" && pwd)
prof="${TMPDIR:-/tmp}/next_customer_chrome_loyalty108dom"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$here/../machine_loyalty_108.html")
timeout 90 "$CHROME" --headless=new --disable-gpu --window-size=1320,900 --virtual-time-budget=4000 --allow-file-access-from-files \
  --user-data-dir="$(to_native "$prof")" --dump-dom "file:///$in?shot=1&$1" 2>/dev/null | grep -o '<title>[^<]*</title>'
