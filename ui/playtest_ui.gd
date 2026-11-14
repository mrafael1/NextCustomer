class_name PlaytestUi
extends RefCounted
## Release gating of the playtest-only UI (polish audit 2026-11-13, batch 1, v1.36): the log
## export (the results' EXPORT LOG key, the pause's link, the shift menu's entry and the title's
## icon), the build label (the title's corner, the shift's seed line) and the title's locked
## LOYAL "SOON" poster show in playtest builds and hide in a release build.
##
## A playtest build is any export whose preset carries the `playtest` feature tag (both presets
## in export_presets.cfg do, so tools/export_web.sh and tools/export_windows.sh keep the log
## export the playtests rely on) and every debug run (the editor, the tests, a debug export). A
## release build is a release export from a preset without the tag.

## The export presets' custom feature tag of a playtest build.
const FEATURE := "playtest"

## Tests force the gate: -1 follows the build, 0 hides the playtest UI, 1 shows it. Screens read
## it when they build, so a test sets it before building one and resets it to -1 after.
static var forced: int = -1


## Whether this build shows the playtest UI.
static func shown() -> bool:
	if forced >= 0:
		return forced == 1
	return OS.has_feature(FEATURE) or OS.is_debug_build()


## The shift's seed line: "Seed n", then the build label in a playtest build.
static func seed_line(run_seed: int) -> String:
	var line: String = "Seed %d" % run_seed
	if shown():
		line += "  ·  %s" % str(ProjectSettings.get_setting("next_customer/build_label", ""))
	return line
