#!/bin/sh
# Re-exports every still of premium_machine_v1.html next to the page (sh stills.sh).
cd "$(dirname "$0")" || exit 1
o=../premium_machine_v1
set -e
sh cap.sh "${o}_board_classic_A_B_C.png" "board=1&at=2" 2240
sh cap.sh "${o}_announce_print_at1.6.png" "scene=announce&at=1.6"
sh cap.sh "${o}_announce_tag_at4.2.png" "scene=announce&at=4.2"
sh cap.sh "${o}_classic_glide_at0.5.png" "scene=classic&at=0.5"
sh cap.sh "${o}_classic_receipt_at1.3.png" "scene=classic&at=1.3"
sh cap.sh "${o}_classic_lit_at3.0.png" "scene=classic&at=3.0"
sh cap.sh "${o}_transform_gold_receipt_at0.9.png" "scene=transform&v=B&at=0.9"
for a in 2.25 2.8 3.5 5.0; do sh cap.sh "${o}_transform_A_at$a.png" "scene=transform&v=A&at=$a"; done
for a in 2.1 2.55 3.1 5.0; do sh cap.sh "${o}_transform_B_at$a.png" "scene=transform&v=B&at=$a"; done
for a in 2.6 3.1 3.25 3.6 5.0; do sh cap.sh "${o}_transform_C_at$a.png" "scene=transform&v=C&at=$a"; done
sh cap.sh "${o}_reveal_packing_at0.8.png" "scene=reveal&p=items&r=R1&at=0.8"
sh cap.sh "${o}_reveal_R1_rare_at1.65.png" "scene=reveal&p=items&r=R1&at=1.65"
sh cap.sh "${o}_reveal_R1_legendary_burst_at2.3.png" "scene=reveal&p=upgrades&v=B&r=R1&at=2.3"
sh cap.sh "${o}_reveal_R1_items_end.png" "scene=reveal&p=items&r=R1&at=4.5"
sh cap.sh "${o}_reveal_R1_coupons_end.png" "scene=reveal&p=coupons&r=R1&at=4.5"
for v in A B C; do
  sh cap.sh "${o}_reveal_R1_loyalty_${v}_end.png" "scene=reveal&p=loyalty&v=$v&r=R1&at=4.5"
  sh cap.sh "${o}_reveal_R1_upgrades_${v}_end.png" "scene=reveal&p=upgrades&v=$v&r=R1&at=4.5"
done
sh cap.sh "${o}_reveal_R2_facedown_at1.4.png" "scene=reveal&p=upgrades&v=B&r=R2&at=1.4"
sh cap.sh "${o}_reveal_R2_tremble_at3.0.png" "scene=reveal&p=upgrades&v=B&r=R2&at=3.0"
sh cap.sh "${o}_reveal_R2_flip_at3.3.png" "scene=reveal&p=upgrades&v=B&r=R2&at=3.3"
sh cap.sh "${o}_reveal_R2_end.png" "scene=reveal&p=upgrades&v=B&r=R2&at=5.5"
