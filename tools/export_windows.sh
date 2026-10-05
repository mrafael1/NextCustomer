#!/bin/sh
# Exports the Windows build (one .exe with the pack embedded) to build/windows/.
set -e
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
mkdir -p build/windows
"$GODOT_BIN" --headless --path . --export-release "Windows Desktop" build/windows/NextCustomer.exe
