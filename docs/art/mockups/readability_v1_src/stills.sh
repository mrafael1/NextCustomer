#!/bin/sh
# Rebuilds ../readability_v1.html and re-exports every still next to it (sh stills.sh).
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
o=../readability_v1
set -e
for v in A B C; do sh cap.sh "${o}_icons_$v.png" "solo=icons&v=$v&at=2.8"; done
for v in A B C; do sh cap.sh "${o}_cards_$v.png" "solo=cards&v=$v&at=1.0"; done
for v in A B C; do sh cap.sh "${o}_cart_$v.png" "solo=cart&v=$v"; done
for v in NOW A B C D; do sh cap.sh "${o}_font_$v.png" "solo=font&v=$v&at=2.8"; done
for v in A B C; do
  sh cap.sh "${o}_monitor_${v}_1_next.png" "solo=monitor&v=$v&at=0.9"
  sh cap.sh "${o}_monitor_${v}_2_scan.png" "solo=monitor&v=$v&at=2.8"
  sh cap.sh "${o}_monitor_${v}_3_wasted.png" "solo=monitor&v=$v&at=5.8"
  sh cap.sh "${o}_monitor_${v}_4_count.png" "solo=monitor&v=$v&at=9.9"
  sh cap.sh "${o}_monitor_${v}_5_met.png" "solo=monitor&v=$v&at=14.5"
done
sh cap.sh "${o}_icons_compare.png" "sec=icons&at=2.8" 1280 4200
sh cap.sh "${o}_cards_compare.png" "sec=cards&at=1.0" 1280 4200
sh cap.sh "${o}_font_compare.png" "sec=font&at=5.8&zoom=2" 1280 3600
sh cap.sh "${o}_monitor_compare.png" "sec=monitor&at=5.8" 1280 2200
sh cap.sh "${o}_monitor_compare_met.png" "sec=monitor&at=14.5&zoom=2" 1280 3600
sh cap.sh "${o}_defaults_bonus.png" "sec=defaults&at=1.0&zoom=2" 1280 1800
sh cap.sh "${o}_first_players.png" "sec=first&at=1.0" 1280 1000
python trim.py "${o}_icons_compare.png" "${o}_cards_compare.png" "${o}_font_compare.png" "${o}_monitor_compare.png" \
  "${o}_monitor_compare_met.png" "${o}_defaults_bonus.png" "${o}_first_players.png"
