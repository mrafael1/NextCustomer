#!/bin/sh
# One polish-audit capture: run_one.sh "<area>|<state>|<sc|au>|<args>" <WxH>
# Writes shots/<area>_<state>_<WxH>.png and logs/<area>_<state>_<WxH>.log (run from the repo root).
line="$1"
size="$2"
area=$(printf '%s' "$line" | cut -d'|' -f1)
state=$(printf '%s' "$line" | cut -d'|' -f2)
kind=$(printf '%s' "$line" | cut -d'|' -f3)
args=$(printf '%s' "$line" | cut -d'|' -f4-)
base=docs/art/mockups/polish_audit
name="${area}_${state}_${size}"
tmp="$base/raw/$name"
rm -rf "$tmp"
mkdir -p "$tmp" "$base/shots" "$base/logs"
if [ "$kind" = "au" ]; then
	# shellcheck disable=SC2086
	timeout 120 godot --path . --resolution "$size" res://debug/screen_capture/capture_audit.tscn -- $args --out="$tmp/out.png" > "$base/logs/$name.log" 2>&1
else
	# shellcheck disable=SC2086
	timeout 120 godot --path . --resolution "$size" res://debug/screen_capture/screen_capture.tscn -- --capture="$tmp" $args > "$base/logs/$name.log" 2>&1
fi
png=$(ls "$tmp"/*.png 2>/dev/null | head -1)
if [ -n "$png" ]; then
	mv "$png" "$base/shots/$name.png"
	echo "OK $name $(basename "$png")"
else
	echo "MISSING $name"
fi
rm -rf "$tmp"
