#!/bin/sh
# Re-imports the project, then parses and type-checks scripts with Godot (warnings are errors),
# then lints and checks formatting. With no arguments it checks every script outside addons/.
# Script paths must not contain spaces.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
if [ $# -eq 0 ]; then
	set -- $(find . -name "*.gd" -not -path "./addons/*" -not -path "./.godot/*" -not -path "./build/*" -not -path "./reports/*" | sed 's#^\./##')
fi
if [ $# -eq 0 ]; then
	echo "No scripts to check."
	exit 0
fi
status=0
for script in "$@"; do
	# Godot can print errors (e.g. a preloaded resource that fails to load) and still exit 0.
	check_status=0
	output=$("$GODOT_BIN" --headless --path . --check-only --script "res://$script" 2>&1) || check_status=$?
	if [ "$check_status" -ne 0 ] || [ -n "$(godot_error_lines "$output")" ]; then
		echo "FAIL parse/type: $script"
		printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g'
		status=1
	fi
done
python -m gdtoolkit.linter "$@" || status=1
python -m gdtoolkit.formatter --check "$@" || status=1
exit $status
