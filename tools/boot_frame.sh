#!/bin/sh
# Rebuilds the boot loader's images and the web shell from the game's own pixels (2026-11-13,
# loading screen look A): art/boot/title_first_frame.png (the title's first frame without its
# corner icons, at art size), art/boot/boot_frame.png (the loader at 0%, the boot splash) and
# export/web_shell.html (export/web_shell_template.html with the receipt's stamps and finished
# frame). Run it after changing the title's storefront at night, the loader's look or the
# shell's template. It opens a 1280x720 window for each capture. Fails on any Godot error.
set -e
cd "$(dirname "$0")/.."
. tools/godot_env.sh
CAPTURE="res://debug/screen_capture/capture_title.tscn"
godot_import
godot_checked --path . --resolution 1280x720 "$CAPTURE" -- --base-frame
godot_import
godot_checked --path . --resolution 1280x720 "$CAPTURE" -- --boot-frame
godot_checked --path . --resolution 1280x720 "$CAPTURE" -- --web-shell
godot_import
echo "Built art/boot/title_first_frame.png, art/boot/boot_frame.png and export/web_shell.html."
