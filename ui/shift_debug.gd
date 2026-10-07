class_name ShiftDebug
extends RefCounted
## The shift screen's development tools (plan section 2): the debug panel (a new run with a
## seed, replaying the impulse rack's logged pick; add a card to the hand; give an upgrade; set
## the shift's inspection; skip to a shift) and the --demo-row command-line option. Split out of
## ShiftScreen to keep that file short; it is a part of the screen and works on its run and
## display through the screen's own methods.
##
## The panel is excluded from playtest exports, so it is only loaded by path here and never
## named by class outside debug/.

const DEBUG_PANEL := "res://debug/debug_panel.tscn"
const CARDS_FOLDER := "res://data/cards"
const UPGRADES_FOLDER := "res://data/upgrades"
const INSPECTIONS_FOLDER := "res://data/inspections"

## The debug panel on the screen, or null in playtest builds.
var panel: Control
var _screen: ShiftScreen
var _log: EventLogService


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log


## Adds the panel to the screen, unless this is a playtest build.
func add_panel(shift_count: int) -> void:
	if OS.has_feature("playtest") or not ResourceLoader.exists(DEBUG_PANEL):
		return
	var scene: PackedScene = load(DEBUG_PANEL)
	panel = scene.instantiate()
	_screen.add_child(panel)
	panel.call("set_shift_count", shift_count)
	panel.connect(&"seed_requested", replay_seed)
	panel.connect(&"card_requested", add_card)
	panel.connect(&"upgrade_requested", give_upgrade)
	panel.connect(&"inspection_requested", set_inspection)
	panel.connect(&"shift_requested", skip_to_shift)


## Whether the game was started with --demo-row (development builds only).
func wants_demo_row() -> bool:
	return not _demo_row_argument().is_empty()


## Development builds only: `godot --path . -- --demo-row=eggs,coffee,banana` starts a new run,
## skips the impulse rack, fills the row with those cards and checks out, to watch (or record)
## the count-up for a chosen row. A demo row always plays a new run and leaves the run save
## untouched: the demo run never writes or deletes it, and a saved run isn't resumed.
func play_demo_row() -> void:
	var argument: String = _demo_row_argument()
	if argument.is_empty():
		return
	await play_row(argument.trim_prefix("--demo-row=").split(",", false))


## The demo row's run for these card ids (see play_demo_row). The rack is skipped like the debug
## replay's "" skip, so run_start logs its times as 0: the player never saw it.
func play_row(card_ids: PackedStringArray) -> void:
	_screen.start_new_run(_log.new_run_seed(), false, "", false)
	_log.log_event("debug", {"action": "demo_row", "cards": Array(card_ids)})
	_screen._replay_impulse_rack("")
	for card_id: String in card_ids:
		var path: String = "%s/%s.tres" % [CARDS_FOLDER, card_id]
		if ResourceLoader.exists(path):
			_screen._pick(_screen.run.debug_add_to_hand(load(path)), false)
			_screen._place_picked(_screen.run.row.size())
	_screen._refresh()
	await _screen.get_tree().create_timer(0.8).timeout
	_screen._on_checkout_pressed()


## A new run with this seed. With `replays_rack`, the impulse rack takes `impulse_pick` (a card
## id, or "" for a skip, as run_start logs it) instead of showing.
func replay_seed(seed_value: int, replays_rack: bool, impulse_pick: String) -> void:
	if _screen._counting:
		return
	var data: Dictionary = {"action": "set_seed", "seed": seed_value}
	if replays_rack:
		data["impulse_pick"] = impulse_pick
	_log.log_event("debug", data)
	_screen.start_new_run(seed_value, replays_rack, impulse_pick)


## Puts a copy of a card into the hand (not the deck). The run save keeps it in the hand.
func add_card(card_id: String) -> void:
	var run: RunState = _screen.run
	if _screen._counting or run.phase != RunState.Phase.PLANNING:
		return
	var path: String = "%s/%s.tres" % [CARDS_FOLDER, card_id]
	if not ResourceLoader.exists(path):
		return
	_log.log_event("debug", {"action": "add_card", "card": card_id})
	run.debug_add_to_hand(load(path))
	_screen._refresh()
	_screen._save_run()


## Gives an upgrade straight away, for testing. The shift restarts (a fresh hand), so its
## redraws are counted again with the new upgrade. An owned upgrade isn't given twice.
func give_upgrade(upgrade_id: String) -> void:
	var run: RunState = _screen.run
	if _screen._counting or run.phase != RunState.Phase.PLANNING:
		return
	var path: String = "%s/%s.tres" % [UPGRADES_FOLDER, upgrade_id]
	if not ResourceLoader.exists(path):
		return
	var upgrade: UpgradeDefinition = load(path)
	if run.upgrades.has(upgrade):
		return
	_log.log_event("debug", {"action": "give_upgrade", "upgrade": upgrade_id})
	run.upgrades.append(upgrade)
	run.debug_skip_to_shift(run.shift_index)
	_screen._refresh_loyalty_card()
	_screen._loyalty_card.play_stamp(run.upgrades.size() - 1)
	_screen._on_shift_started()


## Puts the current shift under an inspection (none for an empty id) and restarts it.
func set_inspection(inspection_id: String) -> void:
	var run: RunState = _screen.run
	var path: String = "%s/%s.tres" % [INSPECTIONS_FOLDER, inspection_id]
	var known: bool = inspection_id.is_empty() or ResourceLoader.exists(path)
	if _screen._counting or run.phase != RunState.Phase.PLANNING or not known:
		return
	_log.log_event("debug", {"action": "set_inspection", "inspection": inspection_id})
	run.inspections = []
	if not inspection_id.is_empty():
		run.inspections.append(load(path))
	run.debug_skip_to_shift(run.shift_index)  # Restarting the shift keeps its inspections.
	_screen._on_shift_started()


func skip_to_shift(shift_number: int) -> void:
	if _screen._counting or _screen.run.phase == RunState.Phase.IMPULSE:
		return
	_log.log_event("debug", {"action": "skip_to_shift", "shift": shift_number})
	var run: RunState = _screen.run
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		# An ended run stays ended: replay its seed, and its impulse-rack choice, as a new run.
		var pick: String = String(run.impulse_pick.id) if run.impulse_pick != null else ""
		_screen.start_new_run(run.run_seed, true, pick)
		if _screen.run.phase != RunState.Phase.PLANNING:
			return  # The replayed pick waits for a deck card to remove.
	_screen.run.debug_skip_to_shift(shift_number - 1)
	_screen._on_shift_started()


## The first --demo-row=... argument, or "" without one or in a playtest build.
func _demo_row_argument() -> String:
	if OS.has_feature("playtest"):
		return ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-row="):
			return argument
	return ""
