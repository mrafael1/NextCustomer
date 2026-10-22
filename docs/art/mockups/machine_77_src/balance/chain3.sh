#!/bin/sh
R=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77/bal/run2.sh
export SEED=1
sh $R b_stamp_items p77_r0 "rarity;floor=2:1,4:2,6:3;itemup;newtiers" 600
sh $R b_rand_floor p77_r0 "reg=rand:0.3;replace;rarity;floor=2:1,4:2,6:3" 600
echo CHAIN3 DONE >> /c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/wt77/reports/p77/index.txt
