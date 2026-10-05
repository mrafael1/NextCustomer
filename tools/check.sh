#!/bin/sh
# Parse and type-check scripts with Godot (warnings are errors), then lint and check formatting.
# With no arguments it checks every script outside addons/.
set -e
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
if [ $# -eq 0 ]; then
	set -- $(find . -name "*.gd" -not -path "./addons/*" -not -path "./.godot/*" | sed 's#^\./##')
fi
status=0
for script in "$@"; do
	if ! output=$("$GODOT_BIN" --headless --path . --check-only --script "res://$script" 2>&1); then
		echo "FAIL parse/type: $script"
		printf '%s\n' "$output"
		status=1
	fi
done
python -m gdtoolkit.linter "$@" || status=1
python -m gdtoolkit.formatter --check "$@" || status=1
exit $status
