#!/bin/sh
# Rebuilds planning_effects_h1.html and planning_effects_h1_hover.html in docs/art/mockups from
# shift_screen_b2_mirrored.html (on main since #84), then captures both at 1920x1080.
HERE=$(cd "$(dirname "$0")" && pwd)
MOCKUPS=$(cd "$HERE/../.." && pwd)
python "$HERE/gen_h1.py" || exit 1
cd "$MOCKUPS" || exit 1
for f in planning_effects_h1 planning_effects_h1_hover; do
  sh "$HERE/cap.sh" "$f.html" "${f}_1920x1080.png" || exit 1
done
