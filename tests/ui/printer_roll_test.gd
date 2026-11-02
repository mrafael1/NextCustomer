extends GdUnitTestSuite
## The receipt printer's roll window (PrinterRoll, shift-scene polish v2 B) on the real shift
## screen: it sits on the printer art's front, inside the printer, the register and the screen
## and clear of the receipt and the slot's lip, in a 1280x720 and a 1600x1000 window, and all it
## draws stays inside the front (the roll and its shiver inside the art's window); a planning
## reprint turns the roll for PLANNING_PRINT_S, then it hides and stops; through a count it turns
## (the roll shivers, the light blinks) and it stops once the count ends; under reduced motion it
## never shows (the art's idle look stays). The saves and logs go to a temporary folder only.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 1000)]
## Milk, Multipack, Milk x5 = 109: passes the first quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## The art's window inside the front (art/src/scenery/printer_box.txt: its slate inside the ink
## frame, front art px).
const WINDOW_INSIDE := Rect2(35, 3, 62, 10)

var _folder: String = ""
## Per counted frame: [printing, visible, shiver, light on].
var _samples: Array[Array] = []
var _roll: PrinterRoll
## _sample bound to the screen, connected to process_frame while a checkout runs.
var _sampler: Callable = Callable()


func before_test() -> void:
	_folder = "user://test_printer_roll_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_samples.clear()


func after_test() -> void:
	Rush.restore()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The roll covers the printer art's front (its lower FRONT_SIZE rows), inside the printer, the
## register and the screen, clear of the receipt and the lip, at both window sizes.
func test_the_roll_sits_on_the_printer_front_inside_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for window_size: Vector2 in WINDOWS:
		screen.size = window_size
		await _frames(3)
		var tag: String = str(window_size)
		var roll: Rect2 = screen._cabinet.printer_roll.get_global_rect()
		var printer: Rect2 = (screen._cabinet.get_node("Printer") as Control).get_global_rect()
		var front: Vector2 = PrinterRoll.FRONT_SIZE * PrinterRoll.SCALE
		assert_that(roll.size).override_failure_message(tag).is_equal(front)
		assert_float(roll.end.y).override_failure_message(tag).is_equal(printer.end.y)
		assert_float(roll.position.x).override_failure_message(tag).is_equal(printer.position.x)
		assert_bool(printer.encloses(roll)).override_failure_message(tag).is_true()
		var register: Rect2 = screen._register.get_global_rect()
		assert_bool(register.encloses(roll)).override_failure_message(tag).is_true()
		var bounds: Rect2 = screen.get_global_rect()
		assert_bool(bounds.encloses(roll)).override_failure_message(tag).is_true()
		var receipt: Rect2 = screen._receipt.get_global_rect()
		assert_bool(roll.intersects(receipt)).override_failure_message(tag).is_false()
		var lip: Rect2 = screen._stage.printer_lip.get_global_rect()
		assert_bool(roll.intersects(lip)).override_failure_message(tag).is_false()


## Everything the roll draws stays on the front, and the roll (shivered down 1 art px too) and the
## glints stay inside the art's window.
func test_the_drawn_parts_stay_inside_the_front_and_the_window() -> void:
	var front: Rect2 = Rect2(Vector2.ZERO, PrinterRoll.FRONT_SIZE)
	for part: Rect2 in [
		PrinterRoll.LIGHT_HOUSING,
		PrinterRoll.LIGHT_GLOW,
		PrinterRoll.KEY_HOUSING,
		PrinterRoll.KEY_GLOW,
	]:
		assert_bool(front.encloses(part)).override_failure_message(str(part)).is_true()
	assert_bool(WINDOW_INSIDE.encloses(PrinterRoll.ROLL_AREA)).is_true()
	var roll: Rect2 = Rect2(PrinterRoll.ROLL_X, PrinterRoll.ROLL_TOP, PrinterRoll.ROLL_WIDTH, 8)
	for drop: int in [0, 1]:
		var dropped: Rect2 = roll
		dropped.position.y += drop
		assert_bool(PrinterRoll.ROLL_AREA.encloses(dropped)).is_true()
	for glint: Vector2i in PrinterRoll.GLINTS:
		var run: Rect2 = Rect2(glint.x, PrinterRoll.GLINT_TOP, glint.y, glint.y)
		(
			assert_bool(PrinterRoll.ROLL_AREA.encloses(run))
			. override_failure_message(str(glint))
			. is_true()
		)
	var last_dash: float = (
		PrinterRoll.LINE_X + (PrinterRoll.LINE_COUNT - 1) * PrinterRoll.LINE_STEP + 3 + 2
	)
	assert_float(last_dash).is_less_equal(PrinterRoll.ROLL_X + PrinterRoll.ROLL_WIDTH)


## A planning reprint (a card placed on the belt) turns the roll for PLANNING_PRINT_S: it shows
## and its phase runs; then it hides, stops processing and its phase stands still.
func test_a_planning_reprint_turns_the_roll_then_it_stops() -> void:
	var screen: ShiftScreen = await _screen()
	var roll: PrinterRoll = screen._cabinet.printer_roll
	await get_tree().create_timer(PrinterRoll.PLANNING_PRINT_S + 0.2).timeout
	assert_bool(roll.visible).is_false()
	await _place(screen, ["milk"])
	assert_bool(roll.is_printing()).is_true()
	assert_bool(roll.visible).is_true()
	var start: float = roll.phase()
	await _frames(3)
	assert_float(roll.phase()).is_greater(start)
	await get_tree().create_timer(PrinterRoll.PLANNING_PRINT_S + 0.2).timeout
	assert_bool(roll.is_printing()).is_false()
	assert_bool(roll.visible).is_false()
	assert_bool(roll.is_processing()).is_false()
	var idle: float = roll.phase()
	await _frames(3)
	assert_float(roll.phase()).is_equal(idle)


## Through a count the roll turns: shown on every counted frame, the roll shivering (both drops
## seen) and the light blinking (on and off seen); once the count ends it is idle again.
func test_the_roll_turns_through_the_count_and_stops_after() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	_roll = screen._cabinet.printer_roll
	_sampler = _sample.bind(screen)
	get_tree().process_frame.connect(_sampler)
	await Rush.checkout(screen)
	get_tree().process_frame.disconnect(_sampler)
	assert_int(_samples.size()).is_greater(10)
	var drops: Dictionary[int, bool] = {}
	var lights: Dictionary[bool, bool] = {}
	for sample: Array in _samples:
		assert_bool(sample[0] and sample[1]).override_failure_message(str(sample)).is_true()
		drops[sample[2]] = true
		lights[sample[3]] = true
	assert_int(drops.size()).is_equal(2)
	assert_int(lights.size()).is_equal(2)
	assert_bool(_roll._counting).is_false()
	await get_tree().create_timer(PrinterRoll.PLANNING_PRINT_S + 0.2).timeout
	assert_bool(_roll.is_printing()).is_false()
	assert_bool(_roll.visible).is_false()


## Reduced motion: neither a planning reprint nor a count shows the roll; the printer stays static.
func test_reduced_motion_keeps_the_printer_static() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _frames(1)  # A burst already turning (the first planning print) stops at once.
	assert_bool(screen._cabinet.printer_roll.visible).is_false()
	var still: float = screen._cabinet.printer_roll.phase()
	await _place(screen, PASSING_ROW)
	_roll = screen._cabinet.printer_roll
	assert_bool(_roll.visible).is_false()
	_sampler = _sample.bind(screen)
	get_tree().process_frame.connect(_sampler)
	await Rush.checkout(screen)
	get_tree().process_frame.disconnect(_sampler)
	assert_int(_samples.size()).is_greater(10)
	for sample: Array in _samples:
		assert_bool(sample[0] or sample[1]).override_failure_message(str(sample)).is_false()
	assert_float(_roll.phase()).is_equal(still)


func _sample(screen: ShiftScreen) -> void:
	if screen._counting and screen._count_up._playing:
		_samples.append([_roll.is_printing(), _roll.visible, _roll.shiver(), _roll.light_on()])


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(1)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
