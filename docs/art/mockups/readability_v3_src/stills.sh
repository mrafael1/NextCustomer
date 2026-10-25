#!/bin/sh
# Rebuilds ../readability_v3.html and re-exports every still next to it (sh stills.sh).
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
o=../readability_v3
set -e
# 1. tickets: the stage at rest, the rail crops, the stress row, the whole section, the Cart
sh cap.sh "${o}_tickets_stage.png" "solo=stage&at=1.7"
sh cap.sh "${o}_tickets_rail.png" "solo=stage&at=0.9"; python zoom.py "${o}_tickets_rail.png" "${o}_tickets_rail.png" 348 404 918 92 2
sh cap.sh "${o}_tickets_stress.png" "solo=stage&stress=1&at=0.9"; python zoom.py "${o}_tickets_stress.png" "${o}_tickets_stress.png" 348 396 918 100 2
sh cap.sh "${o}_tickets_section.png" "sec=ticket&at=0.9" 1280 9000
sh cap.sh "${o}_tickets_vision.png" "sec=vision&at=0.9" 1280 1400
sh cap.sh "${o}_tickets_vision_setB.png" "sec=vision&at=0.9&set=B" 1280 1400
sh cap.sh "${o}_tickets_stress_setB.png" "solo=stage&stress=1&set=B&at=0.9"; python zoom.py "${o}_tickets_stress_setB.png" "${o}_tickets_stress_setB.png" 348 396 918 100 2
sh cap.sh "${o}_cart.png" "solo=cart"
# 2. the monitor count-up, beat by beat (2x crops of the monitor)
for t in 10.54 10.9 11.04 11.08 11.16 13.6 14.0 14.7 15.2 16.5; do
  sh cap.sh "${o}_monitor_${t}.png" "solo=stage&at=$t"; python zoom.py "${o}_monitor_${t}.png" "${o}_monitor_${t}.png" 490 72 412 164 2
done
sh cap.sh "${o}_count_stage.png" "solo=stage&at=11.08"
sh cap.sh "${o}_count_rail.png" "solo=stage&at=11.06"; python zoom.py "${o}_count_rail.png" "${o}_count_rail.png" 348 280 400 220 2
# 3. stacks: the specimens (folded, fanned, style B) and the demo
sh cap.sh "${o}_stacks.png" "sec=badges&at=2.2" 1280 1700
sh cap.sh "${o}_stacks_fan.png" "sec=badges&at=4.0&fan=1" 1280 1700
sh cap.sh "${o}_stacks_B.png" "sec=badges&at=5.36&fold=B" 1280 1700
# 4. highlight to help mixing
for b in 2.6:produce 6.6:breakfast 10.5:milk 13.9:hand 16.2:peas; do
  sh cap.sh "${o}_mix_${b#*:}.png" "solo=mix&at=${b%%:*}"
done
sh cap.sh "${o}_mix_milk_B.png" "solo=mix&at=10.5&mix=B"
sh cap.sh "${o}_mix_cart.png" "solo=cart&carthl=Produce"
# 5. defaults
sh cap.sh "${o}_defaults.png" "sec=defaults&at=1.0" 1280 2200
python trim.py "${o}_tickets_section.png" "${o}_tickets_vision.png" "${o}_tickets_vision_setB.png" "${o}_stacks.png" "${o}_stacks_fan.png" "${o}_stacks_B.png" "${o}_defaults.png"
