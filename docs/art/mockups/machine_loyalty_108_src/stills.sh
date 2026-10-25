#!/bin/sh
# Rebuilds ../machine_loyalty_108.html and re-exports every still next to it (sh stills.sh).
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
o=../machine_loyalty_108
set -e
sh cap.sh "${o}_page_top.png" "" 1320 1300
sh cap.sh "${o}_today.png" "sec=s-today" 1320 1900
sh cap.sh "${o}_dir_A.png" "sec=s-dir&dir=A&row=R1&perks=A_RP" 1320 1520
sh cap.sh "${o}_dir_A_stack.png" "sec=s-dir&dir=A&row=R1&perks=A_RP,A_NP,A_BS" 1320 1520
sh cap.sh "${o}_dir_B.png" "sec=s-dir&dir=B&row=R3&perks=B_CO" 1320 1440
sh cap.sh "${o}_dir_C.png" "sec=s-dir&dir=C&row=R2&perks=C_BC" 1320 1440
sh cap.sh "${o}_ceiling.png" "sec=s-ceil" 1320 900
sh cap.sh "${o}_win.png" "sec=s-win" 1320 1860
sh cap.sh "${o}_questions.png" "sec=s-q" 1320 2240
