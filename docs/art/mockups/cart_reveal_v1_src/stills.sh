#!/bin/sh
# Re-exports every still of cart_reveal_v1.html next to the page (sh stills.sh). Run build.py first.
cd "$(dirname "$0")" || exit 1
o=../cart_reveal_v1
set -e
for v in A B C; do
  case $v in A) m=1.3; l=2.3;; B) m=1.32; l=2.2;; C) m=1.5; l=2.3;; esac
  sh cap.sh "${o}_${v}_0_staples.png" "v=$v&at=0.45&solo=1"
  sh cap.sh "${o}_${v}_1_mid.png" "v=$v&at=$m&solo=1"
  sh cap.sh "${o}_${v}_2_late.png" "v=$v&at=$l&solo=1"
  sh cap.sh "${o}_${v}_3_end.png" "v=$v&at=3.5&solo=1"
done
sh cap.sh "${o}_A_4_outro_fold.png" "v=A&at=3.5&outro=0.18&solo=1"
sh cap.sh "${o}_A_5_outro_cart.png" "v=A&at=3.5&outro=0.6&solo=1"
sh cap.sh "${o}_A_end_deal2.png" "v=A&at=3.5&deal=2&solo=1"
sh cap.sh "${o}_C_end_deal7.png" "v=C&at=3.5&deal=7&solo=1"
sh cap.sh "${o}_page_all.png" "v=all&at=3.5" 1500 1360
