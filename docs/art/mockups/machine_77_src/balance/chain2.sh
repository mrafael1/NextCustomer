#!/bin/sh
R=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77/bal/run2.sh
M="replace;rarity"
SEED=1 sh $R b_stamp_only p77_r0 "rarity;floor=2:1,4:2,6:3" 600
export SEED=1001
sh $R today_b2 balance "" 600
sh $R r0_b2 p77_r0 "" 600
sh $R a_greedy_b2 p77_r0 "reg=greedy;$M" 600
sh $R b_floor_b2 p77_r0 "reg=greedy;$M;floor=2:1,4:2,6:3" 600
sh $R b_items_b2 p77_r0 "reg=greedy;$M;floor=2:1,4:2,6:3;itemup;newtiers" 600
echo CHAIN2 DONE >> /c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/wt77/reports/p77/index.txt
