#!/bin/sh
# Runs every GdUnit4 test headless. Extra arguments go to GdUnit4 (e.g. -a res://tests/core).
# Runs every suite even after a failure (-c), so every failure is reported. Fails if a test
# fails or if Godot prints any error during the run (GdUnit4 doesn't fail a test
# when Godot logs an error, e.g. a resource that fails to load).
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
godot_import
if [ $# -eq 0 ]; then set -- -a res://tests; fi
test_status=0
test_output=$(sh addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c "$@" 2>&1) || test_status=$?
printf '%s\n' "$test_output"
# GdUnit4's runner points the remote debugger at port 0 on purpose (it blocks Godot's interactive
# debugger), which always prints these two errors. They are the only lines ignored.
test_errors=$(godot_error_lines "$test_output" \
	| grep -v -e 'The remote port number must be between 1 and 65535' \
		-e "Remote Debugger: Unable to connect to host '127.0.0.1:0'" || true)
if [ -n "$test_errors" ]; then
	echo "error: Godot printed errors during the test run:" >&2
	printf '%s\n' "$test_errors" >&2
	exit 1
fi
# GdUnit4 exits 0 when it finds nothing to run (e.g. a mistyped suite path).
if printf '%s\n' "$test_output" | grep -q 'No test cases found'; then
	echo "error: no tests ran. Check the suite path." >&2
	exit 1
fi
exit $test_status
