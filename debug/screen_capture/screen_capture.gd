extends Control
## The screen capture (#55, #75; full build plan section 6.1): the real shift screen on fixed
## data, to review the look and to record it in docs/art/. It replaces the style frames, whose
## captures (docs/art/style_frame_*.png and style_frame_v2_*.png) stay as the record of the
## approved frames. #56 adds the other screens.
##
## The shift: shift 5 of 8 on a fixed seed, under Short belt (5 product slots and a CLOSED one),
## with a fixed full hand of 8 items, four items on the belt with their plaques and chips, the
## receipt's planning stub, and a 4-box loyalty card (a starting upgrade and the upgrades of
## shifts 2 and 4 stamped, shift 6's box empty). The hand and the belt hold staples, coupons and
## one product from each of the 6 aisles, so every aisle glyph shows. The screen is the game's
## own and stays playable; it is driven through its public API (start_new_run, debug_show_shift,
## debug_scan) and the run's.
##
## It never touches the player's saves or playtest logs: both go to a temporary folder, deleted
## on exit. Keys: S switches between the sharp-pixel shader and plain nearest filtering (A/B).
## `godot --path . [--resolution 1920x1080] res://debug/screen_capture/screen_capture.tscn --
## --capture=docs/art` saves shift_screen_<width>x<height>.png at the window's size, then quits.
## With `--scan=<card id>` the hover scanner first fully scans that card's item (the belt's first,
## else the hand's), and the file is shift_screen_scan_<width>x<height>.png.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261014
const SHIFT := 5
const INSPECTION := "short_belt"
## The starting upgrade (full build plan 7.3), then the upgrades taken on shifts 2 and 4.
const UPGRADE_IDS: Array[String] = ["coupon_engine", "slot_engine", "category_engine"]
## The hand of 8 (card ids in data/cards), in place of the dealt one: staples, a coupon and a
## product from Pantry, Household and Snacks.
const HAND_IDS: Array[String] = [
	"eggs", "tea_bags", "banana", "batteries", "two_for_one", "crisps", "coffee", "milk"
]
## The cards on the belt: a product from Cold cases, Fruit & veg and Bakery, and a coupon.
const ROW_IDS: Array[String] = ["cheese", "strawberries", "croissant", "multipack"]
const CAPTURE_ARGUMENT := "--capture="
const SCAN_ARGUMENT := "--scan="
## A capture's file name: shift_screen_[scan_]<width>x<height>.png.
const FILE_NAME := "shift_screen_%s%dx%d.png"
const SCAN_PREFIX := "scan_"
## Frames for the shift's items to be laid out before one is scanned.
const SCAN_SETTLE_FRAMES := 2
const CAPTURE_SETTLE_FRAMES := 12

## Where capture() reports a failed save (push_error by default), so tests never print errors.
var report_error: Callable = Callable()
## Grabs the screen for capture() (the viewport's image by default; tests pass their own).
var grab_image: Callable = Callable()

var _folder: String = ""
var _screen: ShiftScreen
var _sharp: bool = true
var _scanned: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Saves and logs go to a temporary folder before the screen loads anything.
	_folder = OS.get_temp_dir().path_join("next_customer_capture_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	_screen = SCREEN.instantiate()
	add_child(_screen)
	_set_up_shift()
	var capture_folder: String = _argument(CAPTURE_ARGUMENT)
	if capture_folder != "":
		var scan_id: String = _argument(SCAN_ARGUMENT)
		if scan_id != "":
			await scan(scan_id)
		await capture(capture_folder)
		get_tree().quit()


func _exit_tree() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_S:
		return
	_sharp = not _sharp
	ArtStyle.set_sharp(self, _sharp)
	get_viewport().set_input_as_handled()


func _set_up_shift() -> void:
	# Past the impulse rack, as the debug replay of a skip.
	_screen.start_new_run(SEED, true, "")
	var run: RunState = _screen.run
	var starter: DeckDefinition = run.starter.duplicate()
	starter.starting_upgrade = _upgrade(UPGRADE_IDS[0])
	run.starter = starter
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: String in UPGRADE_IDS:
		upgrades.append(_upgrade(upgrade_id))
	run.upgrades = upgrades
	run.debug_skip_to_shift(SHIFT - 1)
	# The same shift again: it keeps the inspection set here.
	run.inspections = [load("res://data/inspections/%s.tres" % INSPECTION) as InspectionDefinition]
	run.debug_skip_to_shift(SHIFT - 1)
	# The fixed hand replaces the dealt one, which is set aside for the shift.
	run.deck.restore(run.deck.cards, [], run.deck.draw_pile(), run.deck.next_instance_id())
	for card_id: String in HAND_IDS + ROW_IDS:
		run.debug_add_to_hand(_card(card_id))
	var cards: Array[CardInstance] = run.hand()
	for card: CardInstance in cards.slice(HAND_IDS.size()):
		run.place(card, run.row.size())
	_screen.debug_show_shift()


## The screen being captured (for the smoke test).
func screen() -> ShiftScreen:
	return _screen


## Scans the item of the first card with `card_id` (on the belt, else in the hand) once the
## items are laid out, as the player's hover would; capture() then names its file
## shift_screen_scan_<w>x<h>.png. A card that isn't on the counter goes to report_error.
func scan(card_id: String) -> void:
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	for card: CardInstance in _screen.run.row + _screen.run.hand():
		if card.definition.id == card_id and _screen.debug_scan(card):
			_scanned = true
			return
	_report("No %s on the counter to scan" % card_id)


## Saves the screen into `folder` as shift_screen_<w>x<h>.png (shift_screen_scan_<w>x<h>.png
## after scan()) once it has settled. A failed save goes to report_error.
func capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for _frame: int in range(CAPTURE_SETTLE_FRAMES):
		# A headless run (the tests) draws nothing, so it waits for frames instead.
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	var window: Vector2i = get_window().size
	var prefix: String = SCAN_PREFIX if _scanned else ""
	var path: String = folder.path_join(FILE_NAME % [prefix, window.x, window.y])
	var image: Image = (
		grab_image.call() as Image
		if grab_image.is_valid()
		else get_viewport().get_texture().get_image()
	)
	var error: Error = ERR_UNAVAILABLE if image == null else image.save_png(path)
	if error != OK:
		_report("Can't save %s (error %d)" % [path, error])


func _report(message: String) -> void:
	if report_error.is_valid():
		report_error.call(message)
	else:
		push_error(message)


## The value of the command-line user argument `prefix` (e.g. "--capture="), or "".
static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


static func _card(card_id: String) -> CardDefinition:
	return load("res://data/cards/%s.tres" % card_id) as CardDefinition


static func _upgrade(upgrade_id: String) -> UpgradeDefinition:
	return load("res://data/upgrades/%s.tres" % upgrade_id) as UpgradeDefinition


static func _remove_folder(folder: String) -> void:
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
