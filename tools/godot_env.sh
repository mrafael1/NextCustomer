# Sourced by the other tools scripts. Finds Godot, and provides checked ways to run it:
# Godot exits 0 even when an import, export or test run hits errors, so its output is scanned too.
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
if [ -z "$GODOT_BIN" ]; then
	echo "error: Godot not found. Put 'godot' on the PATH or set GODOT_BIN to the Godot executable." >&2
	exit 1
fi
export GODOT_BIN

# Generated folders are kept out of Godot's import scan.
mkdir -p build reports
touch build/.gdignore reports/.gdignore

# Prints the lines of $1 that report a Godot error.
godot_error_lines() {
	printf '%s\n' "$1" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^(ERROR|SCRIPT ERROR)' || true
}

# Prints a failure: the error lines as a summary, then the whole output for context.
godot_report_failure() {
	echo "error: $1" >&2
	if [ -n "$3" ]; then
		printf '%s\n' "$3" >&2
		echo "--- full Godot output ---" >&2
	fi
	printf '%s\n' "$2" | sed 's/\x1b\[[0-9;]*m//g' >&2
}

# Runs Godot with the given arguments and fails if it exits non-zero or prints an error line.
godot_checked() {
	run_status=0
	run_output=$("$GODOT_BIN" "$@" 2>&1) || run_status=$?
	run_errors=$(godot_error_lines "$run_output")
	if [ "$run_status" -ne 0 ] || [ -n "$run_errors" ]; then
		godot_report_failure "Godot reported errors ($*):" "$run_output" "$run_errors"
		exit 1
	fi
}

# Re-imports the project so class names (class_name) and resource UIDs are current.
# A failed import is reported only once: Godot then marks the asset valid=false in its
# .import file and skips it, so those files are checked as well.
godot_import() {
	godot_checked --headless --path . --import
	# Only the root-level generated folders are skipped; a game folder may also be called build/ or reports/.
	invalid=$(find . \( -path ./.godot -o -path ./build -o -path ./reports -o -path ./.git \) -prune \
		-o -name '*.import' -type f -exec grep -l '^valid=false' {} + || true)
	if [ -n "$invalid" ]; then
		echo "error: these assets failed to import (valid=false):" >&2
		for import_file in $invalid; do
			if [ -e "${import_file%.import}" ]; then
				echo "  $import_file: fix the asset, then delete only the 'valid=false' line (keep the file: it holds the asset's UID)" >&2
			else
				echo "  $import_file: its asset was deleted, so delete this .import file too" >&2
			fi
		done
		exit 1
	fi
}
