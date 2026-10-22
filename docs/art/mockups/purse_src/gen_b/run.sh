#!/bin/sh
# Rebuilds purse_b.html, purse_b_count_up.html and purse_b_states.html in docs/art/mockups (#76, direction B) from
# planning_effects_h1.html, then captures each at 1920x1080 (1280x720 at 1.5x).
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
python "$HERE/gen_b.py" || exit 1
cd "$MOCKUPS" || exit 1
for f in purse_b purse_b_count_up purse_b_states; do
  sh "$HERE/cap.sh" "$f.html" "${f}_1920x1080.png" || exit 1
done
