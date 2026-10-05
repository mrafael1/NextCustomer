#!/bin/sh
# Exports the Windows build (one .exe with the pack embedded) to build/windows/.
# Fails if Godot reports any error.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
mkdir -p build/windows
godot_checked --headless --path . --export-release "Windows Desktop" build/windows/NextCustomer.exe
echo "Exported build/windows/NextCustomer.exe."
