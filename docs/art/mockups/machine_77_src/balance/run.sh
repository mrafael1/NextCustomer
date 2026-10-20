#!/bin/sh
# Usage: sh run.sh NAME BALANCE P77SPEC RUNS [STRATEGY] [MINUTES]
# Runs one scenario of the #77 balance sketch in the worktree, quotas 0, with records.
cd /c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/wt77 || exit 1
name=$1
balance=$2
spec=$3
runs=$4
strategy=${5:-greedy@sensible}
minutes=${6:-10}
mkdir -p reports/p77
export P77="$spec"
start=$(date +%s)
sh tools/balance_sim.sh --runs="$runs" --seed=1 --strategy="$strategy" --quotas=0 \
	--balance="res://data/balance/$balance.tres" --records="res://reports/p77/${name}_records.json" \
	--duel-samples=0 --orphan-samples=0 --offer-samples=0 \
	--max-minutes="$minutes" --cpu-percent=40 > "reports/p77/${name}_full.log" 2>&1
status=$?
cp reports/balance_sim/report.txt "reports/p77/${name}_report.txt" 2>/dev/null
echo "$name status=$status seconds=$(( $(date +%s) - start )) spec=[$spec] balance=$balance" >> reports/p77/index.txt
