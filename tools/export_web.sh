#!/bin/sh
# Exports the single-threaded web build to build/web/.
set -e
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
mkdir -p build/web
"$GODOT_BIN" --headless --path . --export-release "Web" build/web/index.html
