#!/bin/sh
# Runs every GdUnit4 test headless. Extra arguments go to GdUnit4 (e.g. -a res://tests/core).
# Runs every suite even after a failure (-c), so every failure is reported. Fails if a test
# fails or if Godot prints any error during the run (GdUnit4 doesn't fail a test
# when Godot logs an error, e.g. a resource that fails to load).
# The full run (no arguments) also runs the Python tools' tests (tools/*_test.py, unittest)
# with Python 3.11+: $PYTHON if set, else python3, else python.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh

# Prints the Python 3.11+ to use, or fails.
find_python() {
	if [ -n "${PYTHON:-}" ]; then
		set -- "$PYTHON"
	else
		set -- python3 python
	fi
	for candidate in "$@"; do
		if "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 11))' >/dev/null 2>&1; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	echo "error: Python 3.11+ not found. Put python3 or python on the PATH, or set PYTHON." >&2
	return 1
}

godot_import
full_run=0
if [ $# -eq 0 ]; then
	full_run=1
	set -- -a res://tests
fi
test_status=0
test_output=$(sh addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c "$@" 2>&1) || test_status=$?
printf '%s\n' "$test_output"
python_status=0
if [ "$full_run" -eq 1 ]; then
	python_status=1
	if python_bin=$(find_python); then
		python_output=$(PYTHONDONTWRITEBYTECODE=1 "$python_bin" -m unittest discover -s tools \
			-p '*_test.py' 2>&1) && python_status=0
		printf '%s\n' "$python_output"
		# unittest exits 0 when it finds nothing to run (Python 3.11).
		if printf '%s\n' "$python_output" | grep -q '^Ran 0 tests'; then python_status=1; fi
	fi
fi
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
if [ "$python_status" -ne 0 ]; then
	echo "error: the Python tool tests failed (tools/*_test.py)." >&2
	exit 1
fi
exit $test_status
