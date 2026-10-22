#!/bin/sh
# Usage: sh run3.sh NAME BALANCE P77SPEC RUNS [STRATEGY] [MINUTES]  (env SEED, CPU)
# Fix pass of the #77 balance sketch: one scenario in the wt77b worktree, quotas 0, with records.
cd /c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/wt77b || exit 1
name=$1; balance=$2; spec=$3; runs=$4; strategy=${5:-greedy@sensible}; minutes=${6:-10}
mkdir -p reports/p77
export P77="$spec"
start=$(date +%s)
P77NAME="$name" timeout $(( minutes * 60 + 300 )) sh tools/balance_sim_p77.sh --runs="$runs" --seed=${SEED:-1} --strategy="$strategy" --quotas=0 \
	--balance="res://data/balance/$balance.tres" --records="res://reports/p77/${name}_records.json" \
	--duel-samples=0 --orphan-samples=0 --offer-samples=0 --cache="res://reports/balance_sim_cache_${name}" \
	--max-minutes="$minutes" --cpu-percent=${CPU:-30} > "reports/p77/${name}_full.log" 2>&1
status=$?
echo "$name status=$status seconds=$(( $(date +%s) - start )) spec=[$spec] balance=$balance strategy=$strategy" >> reports/p77/index.txt
