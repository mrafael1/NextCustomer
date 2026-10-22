#!/bin/sh
R=$(dirname "$0")/run4.sh
B="rarity;floor=2:1,4:2,6:3"
sh $R split_blind "$B;itemup;upblind;itemsfix;prodrarity;split" 600 greedy@sensible 28
sh $R split_breakfast "$B;itemup;upblind;itemsfix;prodrarity;split" 600 build:breakfast_special@sensible 28
sh $R prodrarity_only "$B;itemsfix;prodrarity" 600 greedy@sensible 22
echo CHAIN DONE
