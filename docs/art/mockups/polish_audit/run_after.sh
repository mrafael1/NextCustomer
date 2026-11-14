#!/bin/sh
# Re-captures for a polish pass: run_after.sh <specs file> (run from the repo root).
# Each line "<area>|<state>|<sc|au>|<args>" is captured at 1920x1080 and 1280x720 into
# docs/art/mockups/polish_audit/after/<area>_<state>_<WxH>.png (logs in after/logs/).
base=docs/art/mockups/polish_audit
out="$base/after"
mkdir -p "$out/logs"
while IFS= read -r line; do
	[ -z "$line" ] && continue
	for size in 1920x1080 1280x720; do
		area=$(printf '%s' "$line" | cut -d'|' -f1)
		state=$(printf '%s' "$line" | cut -d'|' -f2)
		kind=$(printf '%s' "$line" | cut -d'|' -f3)
		args=$(printf '%s' "$line" | cut -d'|' -f4-)
		name="${area}_${state}_${size}"
		tmp="$base/raw/$name"
		rm -rf "$tmp"
		mkdir -p "$tmp"
		if [ "$kind" = "au" ]; then
			# shellcheck disable=SC2086
			timeout 120 godot --path . --resolution "$size" res://debug/screen_capture/capture_audit.tscn -- $args --out="$tmp/out.png" > "$out/logs/$name.log" 2>&1
		else
			# shellcheck disable=SC2086
			timeout 120 godot --path . --resolution "$size" res://debug/screen_capture/screen_capture.tscn -- --capture="$tmp" $args > "$out/logs/$name.log" 2>&1
		fi
		png=$(ls "$tmp"/*.png 2>/dev/null | head -1)
		if [ -n "$png" ]; then
			mv "$png" "$out/$name.png"
			echo "OK $name"
		else
			echo "MISSING $name"
		fi
		rm -rf "$tmp"
	done
done < "$1"
rmdir "$base/raw" 2>/dev/null
exit 0
