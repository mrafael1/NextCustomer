#!/bin/sh
# #77 balance fix pass (2026-10-20): four scenarios in parallel in the wt77b worktree. Each run has
# its own work dir (tools/balance_sim_p77.sh, P77NAME) and its own search cache, so parallel runs
# never share shard files. 4 runs x 25% CPU.
B=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77/bal
R=$B/run3.sh
F="floor=2:1,4:2,6:3"
export CPU=25
sh $R b_stamp_items_blind p77_r0 "rarity;$F;itemup;newtiers;upblind;itemsfix" 600 greedy@sensible 22 &
sh $R b_stamp_rerun p77_r0 "rarity;$F" 206 greedy@sensible 26 &
sh $R b_stamp_fits p77_r0 "rarity;fits;$F" 600 greedy@sensible 22 &
sh $R b_stamp_breakfast p77_r0 "rarity;$F" 600 build:breakfast_special@sensible 22 &
wait
echo FIXPASS DONE
