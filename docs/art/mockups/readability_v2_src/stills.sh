#!/bin/sh
# Rebuilds ../readability_v2.html and re-exports every still next to it (sh stills.sh).
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
o=../readability_v2
set -e
for v in A B C; do sh cap.sh "${o}_ticket_${v}.png" "solo=stage&v1=$v&at=1.7"; done
# the stress rows: only the rail (the belt above it shows the normal six items)
for v in A B C; do
  sh cap.sh "${o}_ticket_${v}_stress.png" "solo=stage&stress=1&v1=$v&at=0.9"
  python zoom.py "${o}_ticket_${v}_stress.png" "${o}_ticket_${v}_stress.png" 348 396 918 104 1
done
for v in a b; do
  sh cap.sh "${o}_monitor_${v}_1_next.png" "solo=stage&v2=$v&at=0.9"
  sh cap.sh "${o}_monitor_${v}_2_scan.png" "solo=stage&v2=$v&at=4.9"
  sh cap.sh "${o}_monitor_${v}_3_wasted.png" "solo=stage&v2=$v&at=7.7"
  sh cap.sh "${o}_monitor_${v}_4_count.png" "solo=stage&v2=$v&at=11.8"
  sh cap.sh "${o}_monitor_${v}_4b_climax.png" "solo=stage&v2=$v&at=15.4"
  sh cap.sh "${o}_monitor_${v}_5_met.png" "solo=stage&v2=$v&at=16.5"
done
sh cap.sh "${o}_icons.png" "sec=icons&at=1.7" 1280 2000
sh cap.sh "${o}_tickets_compare.png" "sec=ticket&at=0.9" 1280 4600
sh cap.sh "${o}_monitor_compare.png" "sec=monitor&at=11.8&zoom=2" 1280 3400
sh cap.sh "${o}_badges.png" "sec=badges&at=1.4" 1280 1700
sh cap.sh "${o}_badges_fire.png" "sec=badges&at=2.35" 1280 1700
sh cap.sh "${o}_defaults.png" "sec=defaults&at=1.0" 1280 1800
# a synthetic hover on a ticket glyph in a stage scaled down to a 900 px window (checks hover inside scaled stages)
sh cap.sh "${o}_hover_900.png" "sec=ticket&at=0.3&hovertest=1" 900 1000
python zoom.py "${o}_hover_900.png" "${o}_hover_900.png" 0 450 900 550 1
python trim.py "${o}_icons.png" "${o}_tickets_compare.png" "${o}_monitor_compare.png" "${o}_badges.png" "${o}_badges_fire.png" "${o}_defaults.png"
