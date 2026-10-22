#!/bin/sh
# Rebuilds the #56 deck-view mock-ups (screens_deck_a*, screens_deck_b*) in docs/art/mockups and
# captures each at 1920x1080 (1280x720 at 1.5x) in headless Chrome. CHROME picks the browser; the
# profile is a throwaway folder under TMPDIR, removed afterwards.
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/next_customer_chrome_deck56"
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
python "$HERE/gen_deck.py" || exit 1
cd "$MOCKUPS" || exit 1
for f in screens_deck_a screens_deck_a_info screens_deck_a_stock screens_deck_a_chooser screens_deck_b screens_deck_b_info screens_deck_b_stock screens_deck_b_chooser; do
  in=$(to_native "$(realpath "$f.html")")
  out=$(to_native "$(realpath -m "${f}_1920x1080.png")")
  timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
    --window-size=1280,720 --virtual-time-budget=3000 --user-data-dir="$(to_native "$prof")" \
    --screenshot="$out" "file:///$in" >/dev/null 2>&1
  test -s "${f}_1920x1080.png" && echo "wrote ${f}_1920x1080.png" || { echo "capture failed: $f"; exit 1; }
  # The fit numbers the page measured (content height of the page area, panel rect).
  timeout 90 "$CHROME" --headless=new --disable-gpu --window-size=1280,720 --virtual-time-budget=3000 \
    --user-data-dir="$(to_native "$prof")" --dump-dom "file:///$in" 2>/dev/null | grep -o 'data-[a-z]*="[^"]*"' | tr '\n' ' '
  echo
done
rm -rf "$prof"
