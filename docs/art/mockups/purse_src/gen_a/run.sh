#!/bin/sh
# Rebuilds purse_a.html, purse_a_count_up.html and purse_a_states.html in docs/art/mockups, then captures each at 1920x1080.
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
python "$HERE/gen_a.py" || exit 1
cd "$MOCKUPS" || exit 1
for f in purse_a purse_a_count_up purse_a_states; do
  sh "$HERE/cap.sh" "$f.html" "${f}_1920x1080.png" || exit 1
done
