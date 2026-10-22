#!/bin/sh
# usage (repo root, Git Bash): sh docs/art/mockups/screens_src/gen_title/cap_all.sh
# Captures every screens_title_* page at 1920x1080 (1280x720 at 1.5x) with headless Chrome; throwaway profile under TMPDIR.
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/next_customer_chrome56_title"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
for page in docs/art/mockups/screens_title_*.html; do
  outp="${page%.html}_1920x1080.png"
  in=$(to_native "$(realpath "$page")"); out=$(to_native "$(realpath -m "$outp")")
  timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
    --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
    --screenshot="$out" "file:///$in" >/dev/null 2>&1
  test -s "$outp" && echo "wrote $outp" || echo "capture failed: $page"
done
rm -rf "$prof"
