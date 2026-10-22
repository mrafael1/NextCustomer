#!/bin/sh
# Usage: sh run5.sh NAME P77SPEC RUNS STRATEGY MINUTES [SEED]  -- round 3 (inspection bonus ticket), one at a time, 60% CPU
[ -e "${P77C:?set P77C to the scratch folder}/STOP" ] && { echo "$1 skipped (STOP)"; exit 0; }
cd "${P77C:?set P77C to the scratch folder}/wt" || exit 1
name=$1; spec=$2; runs=$3; strategy=$4; minutes=$5; seed=${6:-1}
mkdir -p reports/p77
export P77="$spec"
start=$(date +%s)
P77NAME="$name" timeout $(( minutes * 60 + 400 )) sh tools/balance_sim_p77.sh --runs="$runs" --seed="$seed" --strategy="$strategy" --quotas=0 	--balance="res://data/balance/p77_r0.tres" --records="res://reports/p77/${name}_records.json" 	--duel-samples=0 --orphan-samples=0 --offer-samples=0 --cache="res://reports/balance_sim_cache_${name}" 	--max-minutes="$minutes" --cpu-percent=60 > "reports/p77/${name}_full.log" 2>&1
status=$?
echo "$name status=$status seconds=$(( $(date +%s) - start )) seed=$seed spec=[$spec] strategy=$strategy" >> reports/p77/index.txt
