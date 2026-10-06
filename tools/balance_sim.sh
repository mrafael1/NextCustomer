#!/bin/sh
# Runs the headless balance simulator (plan section 8), split over several Godot processes
# (worker threads sharing the card resources ran slower than one thread). Arguments go to the
# simulator, e.g.
#   sh tools/balance_sim.sh --runs=200 --strategy=greedy,random,skip --out=reports/sim.json
# The options are listed in tools/balance_sim/balance_sim.gd. --jobs=N sets the number of
# processes (default: the number of CPUs). The report is also saved to
# reports/balance_sim/report.txt. Fails if Godot prints any error (e.g. a best row that
# checkout scored differently from the search).
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
jobs=$(nproc 2>/dev/null || echo 4)
count=$#
while [ "$count" -gt 0 ]; do
	argument=$1
	shift
	count=$((count - 1))
	case "$argument" in
		--jobs=*) jobs=${argument#--jobs=} ;;
		*) set -- "$@" "$argument" ;;
	esac
done
godot_import
work=reports/balance_sim
rm -rf "$work"
mkdir -p "$work"
started=$(date +%s)
pids=""
shards=""
index=0
while [ "$index" -lt "$jobs" ]; do
	"$GODOT_BIN" --headless --path . --script res://tools/balance_sim/balance_sim.gd -- "$@" \
		--shard="$index/$jobs" --raw="res://$work/shard_$index.json" > "$work/shard_$index.log" 2>&1 &
	pids="$pids $!"
	shards="$shards,res://$work/shard_$index.json"
	index=$((index + 1))
done
echo "Simulating in $jobs processes. Progress of the first one:"
first_pid=${pids# }
first_pid=${first_pid%% *}
tail -n +1 -f --pid="$first_pid" "$work/shard_0.log" 2>/dev/null || true
status=0
for pid in $pids; do
	wait "$pid" || status=1
done
errors=""
for log in "$work"/shard_*.log; do
	errors="$errors$(godot_error_lines "$(cat "$log")")"
done
if [ "$status" -ne 0 ] || [ -n "$errors" ]; then
	echo "error: a simulator process failed (logs in $work/):" >&2
	printf '%s\n' "$errors" >&2
	exit 1
fi
echo "Merging after $(( $(date +%s) - started )) s..."
merge_status=0
"$GODOT_BIN" --headless --path . --script res://tools/balance_sim/balance_sim.gd -- "$@" \
	--merge="${shards#,}" > "$work/report.txt" 2>&1 || merge_status=$?
cat "$work/report.txt"
errors=$(godot_error_lines "$(cat "$work/report.txt")")
if [ "$merge_status" -ne 0 ] || [ -n "$errors" ]; then
	echo "error: merging the simulator results failed:" >&2
	printf '%s\n' "$errors" >&2
	exit 1
fi
echo "Total $(( $(date +%s) - started )) s"
