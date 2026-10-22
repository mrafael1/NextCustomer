#!/bin/sh
R=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77/bal/run.sh
M="replace;rarity"
sh $R today balance "" 600
sh $R r0 p77_r0 "" 600
sh $R a_greedy p77_r0 "reg=greedy;$M" 600
sh $R b_floor p77_r0 "reg=greedy;$M;floor=2:1,4:2,6:3" 600
sh $R b_items p77_r0 "reg=greedy;$M;floor=2:1,4:2,6:3;itemup;newtiers" 600
sh $R today_items p77_r0 "reg=sched:2.4.6;itemup;newtiers" 600
sh $R b_pity p77_r0 "reg=greedy;$M;floor=4:1" 600
sh $R a_rand p77_r0 "reg=rand:0.3;$M" 600
sh $R r1 p77_r1 "" 600
sh $R r2 p77_r2 "" 600
sh $R r0_skip p77_r0 "" 600 skip@sensible
sh $R today_skip balance "" 600 skip@sensible
echo CHAIN1 DONE >> /c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/wt77/reports/p77/index.txt
