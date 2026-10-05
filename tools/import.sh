#!/bin/sh
# Re-imports the project and fails on any import error, including assets Godot
# marked valid=false in an earlier import.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
echo "Import OK."
