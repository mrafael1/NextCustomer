#!/bin/sh
# Checks the puzzle shifts (#183, docs/FULL_BUILD_PLAN.md section 7.6): for each puzzle of
# data/puzzles/puzzle_list.tres it tries every row the hand can make (PuzzleSolver) and reports
# how many distinct rows hit the target.
#   sh tools/puzzle_check.sh [--puzzle=ID] [--totals]
# --puzzle checks one puzzle; --totals also lists every reachable total with its row count (for
# authoring a target). Fails on a puzzle with a data problem, no solution, or a stored solution
# that misses its target; warns when more rows than the list's max_solutions hit it. The report
# is also saved to reports/puzzle_check/report.txt. Fails if Godot prints any error.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
mkdir -p reports/puzzle_check
godot_checked --headless --path . --script res://tools/puzzle_check/puzzle_check.gd -- "$@"
printf '%s\n' "$run_output" > reports/puzzle_check/report.txt
printf '%s\n' "$run_output"
