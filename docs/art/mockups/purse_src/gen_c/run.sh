#!/bin/sh
# Rebuilds purse_c.html, purse_c_count_up.html and purse_c_states.html in docs/art/mockups from planning_effects_h1.html,
# then captures each at 1920x1080 (1280x720 at 1.5x) with headless Chrome.
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
python "$HERE/gen_c.py" || exit 1
cd "$MOCKUPS" || exit 1
for f in purse_c purse_c_count_up purse_c_states; do
  sh "$HERE/cap.sh" "$f.html" "${f}_1920x1080.png" || exit 1
done
