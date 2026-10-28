#!/bin/sh
# Rebuilds ../starter_choice_107.html and re-exports every still next to it (sh stills.sh).
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
o=../starter_choice_107
set -e
# the default layout (A, in the reveal), beat by beat; q2=B shutters today's 6
sh cap.sh "${o}_A_1_deal.png" "solo=stage&lay=A&at=2.2"
sh cap.sh "${o}_A_2_stock_hover.png" "solo=stage&lay=A&at=3.0"
sh cap.sh "${o}_A_3_pack_hover.png" "solo=stage&lay=A&at=5.3"
sh cap.sh "${o}_A_4_raised.png" "solo=stage&lay=A&at=7.65"
sh cap.sh "${o}_A_5_pick.png" "solo=stage&lay=A&at=8.45"
sh cap.sh "${o}_A_6_end.png" "solo=stage&lay=A&at=11.6"
sh cap.sh "${o}_A_7_hidden_stock.png" "solo=stage&lay=A&q2=B&at=5.3"
# the two places that were ruled out
sh cap.sh "${o}_B_1_hover.png" "solo=stage&lay=B&at=2.4"
sh cap.sh "${o}_B_2_fly.png" "solo=stage&lay=B&at=6.5"
sh cap.sh "${o}_B_3_reveal.png" "solo=stage&lay=B&at=7.6"
sh cap.sh "${o}_C_1_hover.png" "solo=stage&lay=C&at=3.6"
sh cap.sh "${o}_C_2_picked.png" "solo=stage&lay=C&at=6.0"
sh cap.sh "${o}_C_3_flow.png" "solo=stage&lay=C&at=8.6"
# the page's sections
sh cap.sh "${o}_page_top.png" "at=3" 1280 900
sh cap.sh "${o}_q1_board.png" "sec=q1&at=4" 1280 1100
sh cap.sh "${o}_q2_today.png" "sec=q2&at=3.0" 1280 1400
sh cap.sh "${o}_packs.png" "sec=packs" 1280 2400
sh cap.sh "${o}_q3_first_run.png" "sec=q3" 1280 1000
sh cap.sh "${o}_q4_banana.png" "sec=q4&at=4.9" 1280 1400
sh cap.sh "${o}_defaults.png" "sec=defaults" 1280 1300
python trim.py "${o}_q1_board.png" "${o}_q2_today.png" "${o}_packs.png" "${o}_q3_first_run.png" "${o}_q4_banana.png" "${o}_defaults.png"
