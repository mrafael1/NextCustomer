#!/bin/sh
# usage: sh dom.sh "<query>": loads ../readability_v3.html headless and prints the page title (it carries
# "OVERFLOW:<ids>" when a ticket's text does not fit) and any console error.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
here=$(cd "$(dirname "$0")" && pwd)
prof="${TMPDIR:-/tmp}/next_customer_chrome_readability3dom"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
in=$(to_native "$here/../readability_v3.html")
timeout 90 "$CHROME" --headless=new --disable-gpu --window-size=1280,720 --virtual-time-budget=6000 --allow-file-access-from-files \
  --enable-logging=stderr --v=0 --user-data-dir="$(to_native "$prof")" --dump-dom "file:///$in?shot=1&$1" 2>/dev/null | grep -o '<title>[^<]*</title>'
