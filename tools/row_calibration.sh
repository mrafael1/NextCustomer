#!/bin/sh
# Compares the balance simulator's sensible row player with logged players (issue #41): it
# replays the checkouts in playtest logs and reports how close each comes to the exact best row.
#   sh tools/row_calibration.sh [--logs=PATH,PATH]
# (default: the desktop game's playtest_logs folder). The report is also saved to
# reports/row_calibration/report.txt. Fails if Godot prints any error.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
mkdir -p reports/row_calibration
godot_checked --headless --path . --script res://tools/balance_sim/row_calibration.gd -- "$@"
printf '%s\n' "$run_output" > reports/row_calibration/report.txt
printf '%s\n' "$run_output"
