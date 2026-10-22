#!/bin/sh
until grep -q "CHAIN DONE" ${P77C:?set P77C to the scratch folder}/chain.log; do sleep 10; done
rm -f ${P77C:?set P77C to the scratch folder}/STOP
R=${P77C:?set P77C to the scratch folder}/run5.sh
B="rarity;floor=2:1,4:2,6:3"
S="$B;itemup;upblind;itemsfix;prodrarity;split;bonus"
sh $R bonus_greedy_b2 "$S" 600 greedy@sensible 10 1001
sh $R bonus_rare_b2 "$S;rarityfile=p77_rarity_b.json" 600 greedy@sensible 10 1001
sh $R bonus_breakfast "$S" 600 build:breakfast_special@sensible 32
sh $R bonus_rare_s1 "$S;rarityfile=p77_rarity_b.json;bonusextra=1" 600 greedy@sensible 32
echo CHAIN2 DONE
