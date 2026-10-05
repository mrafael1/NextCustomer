#!/bin/sh
# Runs every GdUnit4 test headless. Extra arguments go to GdUnit4 (e.g. -a res://tests/core).
set -e
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
export GODOT_BIN
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1
if [ $# -eq 0 ]; then set -- -a res://tests; fi
sh addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode "$@"
