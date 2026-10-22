#!/bin/sh
# Runs the headless balance simulator (plan section 8), split over several Godot processes
# (worker threads sharing the card resources ran slower than one thread). Arguments go to the
# simulator, e.g.
#   sh tools/balance_sim.sh --runs=200 --strategy=greedy,random,skip --out=reports/sim.json
# The options are listed in tools/balance_sim/balance_sim.gd (--max-minutes=N stops it after N
# minutes, default 15). --cpu-percent=P keeps it to P% of the CPUs (default 80: one process per
# CPU in that share, at least one); --jobs=N sets the number of processes instead. The report is
# also saved to
# reports/balance_sim/report.txt. Fails if Godot prints any error (e.g. a best row that
# checkout scored differently from the search).
# The processes run on one of Godot's Windows export templates, with the project exported as a
# pack (the "Balance simulator" preset) to a folder of its own under build/balance_sim/, so
# several simulations can run at once; the folder is removed when the wrapper exits. The
# default --runner=debug uses the debug template: faster than the editor binary, and it still
# prints GDScript runtime errors (SCRIPT ERROR), which the error check needs.
# --runner=release uses the release template: faster again, but a release build compiles
# GDScript runtime errors out (a bad index gives null and the run goes on), so a bug can give
# wrong records with no error; use it only for code that a debug or editor run has already
# passed. --runner=editor uses the editor binary. All three give the same records. The
# templates are Godot's export templates for this version (the ones tools/export_windows.sh
# needs); without them, or off Windows, the editor binary is used.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
cpus=$(nproc 2>/dev/null || echo 4)
cpu_percent=80
jobs=""
runner=debug
# The repo root as Godot reads it (C:/... in Git Bash), for paths the exported pack can't see.
root=$(pwd -W 2>/dev/null || pwd)
count=$#
while [ "$count" -gt 0 ]; do
	argument=$1
	shift
	count=$((count - 1))
	case "$argument" in
		--jobs=*) jobs=${argument#--jobs=} ;;
		--cpu-percent=*) cpu_percent=${argument#--cpu-percent=} ;;
		--runner=*) runner=${argument#--runner=} ;;
		# A profile save is read as a file, and the pack holds no .json files.
		--profile=res://*) set -- "$@" "--profile=$root/${argument#--profile=res://}" ;;
		*) set -- "$@" "$argument" ;;
	esac
done
if [ "$runner" != debug ] && [ "$runner" != release ] && [ "$runner" != editor ]; then
	echo "error: --runner takes debug, release or editor, got $runner" >&2
	exit 1
fi
if [ -z "$jobs" ]; then
	jobs=$((cpus * cpu_percent / 100))
	[ "$jobs" -ge 1 ] || jobs=1
fi
godot_import
work=reports/balance_sim
rm -rf "$work"
mkdir -p "$work"
started=$(date +%s)
simulator="$GODOT_BIN"
simulator_args="--headless --path . --script res://tools/balance_sim/balance_sim.gd"
raw_root="res://"
if [ "$runner" != editor ]; then
	version=$("$GODOT_BIN" --version | sed -E 's/^([0-9.]+[a-z0-9]+)\..*/\1/')
	templates="${APPDATA:-}/Godot/export_templates/$version"
	template="$templates/windows_${runner}_x86_64"
	if [ -n "${APPDATA:-}" ] && [ -f "${template}_console.exe" ]; then
		# Folders left by a wrapper that was killed (its process is gone) are removed.
		for stale in build/balance_sim/run_*; do
			[ -d "$stale" ] || continue
			kill -0 "${stale##*run_}" 2>/dev/null || rm -rf "$stale" 2>/dev/null || true
		done
		out=build/balance_sim/run_$$
		rm -rf "$out"
		mkdir -p "$out"
		trap 'rm -rf "$out" 2>/dev/null || true' EXIT
		godot_checked --headless --path . --export-pack "Balance simulator" "$out/balance_sim.pck"
		# Hard links (copies where the file system has none): the templates are about 100 MB.
		ln "$template.exe" "$out/balance_sim.exe" 2>/dev/null || cp "$template.exe" "$out/balance_sim.exe"
		ln "${template}_console.exe" "$out/balance_sim.console.exe" 2>/dev/null 			|| cp "${template}_console.exe" "$out/balance_sim.console.exe"
		# The pack's main loop is the simulator (a template ignores --script), with an empty
		# main scene instead of the game's title screen.
		printf '[application]

%s
%s
' 			'run/main_scene="res://tools/balance_sim/balance_sim_main.tscn"' 			'run/main_loop_type="BalanceSim"' > "$out/override.cfg"
		# The pack holds no source text to fingerprint, so the editor binary names the cache.
		godot_checked $simulator_args -- "$@" --cache-name
		cache_file=$(printf '%s
' "$run_output" | sed -n 's/^cache-file=//p' | tr -d '')
		if [ -n "$cache_file" ]; then
			set -- "$@" "--cache-file=$cache_file"
		fi
		simulator="$out/balance_sim.console.exe"
		simulator_args="--headless"
		raw_root="$root/"
	else
		echo "No Windows $runner export template for Godot $version: using the editor binary."
		runner=editor
	fi
fi
pids=""
shards=""
index=0
while [ "$index" -lt "$jobs" ]; do
	"$simulator" $simulator_args -- "$@" \
		--shard="$index/$jobs" --raw="$raw_root$work/shard_$index.json" > "$work/shard_$index.log" 2>&1 &
	pids="$pids $!"
	shards="$shards,$raw_root$work/shard_$index.json"
	index=$((index + 1))
done
echo "Simulating in $jobs processes ($cpus CPUs, $runner runner). Progress of the first one:"
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
