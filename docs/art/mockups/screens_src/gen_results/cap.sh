#!/bin/sh
# usage (repo root, Git Bash): sh docs/art/mockups/screens_src/gen_results/cap.sh  -> captures every screens_results_*.html at 1920x1080
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
prof="${TMPDIR:-/tmp}/chrome56_results"
for page in docs/art/mockups/screens_results_*.html; do
  png="${page%.html}_1920x1080.png"
  in=$(cygpath -m "$(realpath "$page")"); out=$(cygpath -w "$(realpath -m "$png")")
  timeout 90 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 --window-size=1280,720 \
    --virtual-time-budget=3000 --user-data-dir="$(cygpath -w "$prof")" --screenshot="$out" "file:///$in" >/dev/null 2>&1
  test -s "$png" && echo "wrote $png" || echo "capture failed: $page"
done
rm -rf "$prof"
