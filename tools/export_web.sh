#!/bin/sh
# Exports the single-threaded web build to build/web/. Fails if Godot reports any error.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
mkdir -p build/web
godot_checked --headless --path . --export-release "Web" build/web/index.html
echo "Exported build/web/."
