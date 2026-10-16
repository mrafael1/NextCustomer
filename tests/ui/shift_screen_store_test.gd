extends GdUnitTestSuite
## The shift screen's store look (#80, mock-up B2's greybox): the backdrop's window bands (the
## top bar's band, the plaster wall, which keeps the background clicks, the counter's wood and
## the floor) at 1280x720 and at 1920x1080; the belt's bands; the register (RegisterCabinet) with
## its printer, column, keypad and drawer at their rects; decor that never takes a click (a click
## on an empty slot or a hand card still reaches it, and one on the bare belt or the monitor
## reaches the wall); the hand's items and baskets fading while the shift is counted. The real
## saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## In a 1280x720 and a 1920x1080 window: the wall fills the window and takes the clicks; the top
## band runs from the window's top to the stage's top bar foot, the counter from the stage's
## counter line to the bottom and the floor from the stage's floor line to the bottom, each
## spanning the window and taking no click; the stage is centred.
func test_the_backdrop_fits_each_window() -> void:
	for window_size: Vector2 in WINDOWS:
		var window: Control = auto_free(Control.new())
		window.size = window_size
		add_child(window)
		var wall: ColorRect = StoreBackdrop.screen_parts(window)
		var stage: ShiftStage = ShiftStage.new(7)
		window.add_child(stage)
		await _frames(2)
		var bounds: Rect2 = window.get_global_rect()
		var stage_rect: Rect2 = stage.get_global_rect()
		assert_vector(stage_rect.size).is_equal(ShiftStage.SIZE)
		assert_vector(stage_rect.get_center()).is_equal_approx(bounds.get_center(), Vector2.ONE)
		assert_object(window.get_child(0)).is_same(wall)
		assert_that(wall.get_global_rect()).is_equal(bounds)
		assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
		var top_band: Rect2 = _band(window, "TopBand", bounds)
		assert_float(top_band.position.y).is_less_equal(bounds.position.y)
		assert_float(top_band.end.y).is_equal(stage_rect.position.y + ShiftStage.TOP_BAR_BOTTOM)
		var counter: Rect2 = _band(window, "Counter", bounds)
		assert_float(counter.position.y).is_equal(stage_rect.position.y + ShiftStage.COUNTER_TOP)
		assert_float(counter.end.y).is_greater_equal(bounds.end.y)
		var floor_band: Rect2 = _band(window, "Floor", bounds)
		assert_float(floor_band.position.y).is_equal(stage_rect.position.y + ShiftStage.FLOOR_TOP)
		assert_float(floor_band.end.y).is_greater_equal(bounds.end.y)
		window.queue_free()


## The belt's bands: the top face the items stand on and the rail the tickets clip onto, inside
## the belt, the rail under the top face.
func test_the_belt_draws_its_bands() -> void:
	var screen: ShiftScreen = await _screen()
	var belt: BeltPanel = screen._stage.belt
	var inside: Rect2 = Rect2(Vector2.ZERO, belt.size)
	assert_vector(belt.size).is_equal(ShiftStage.BELT_RECT.size)
	for band: Rect2 in [belt.top_face(), belt.rail()]:
		assert_bool(inside.encloses(band)).override_failure_message(str(band)).is_true()
	assert_float(belt.rail().position.y).is_greater_equal(belt.top_face().end.y)
	var top_face: Rect2 = belt.get_global_transform() * belt.top_face()
	assert_float(top_face.position.y).is_equal(
		screen._stage.get_global_rect().position.y + ShiftStage.COUNTER_TOP
	)


## Decor takes no click: the window bands other than the wall, the belt, the monitor, the
## baskets and the register (with every part of them) are MOUSE_FILTER_IGNORE. A click on an
## empty slot or a hand card reaches it, and one on the bare belt between two slots or on the
## monitor reaches the wall (the background click).
func test_decor_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var wall: Control = screen.get_child(0) as Control
	assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(wall.gui_input.is_connected(screen._on_background_input)).is_true()
	for index: int in range(1, stage.get_index()):
		var part: Control = screen.get_child(index) as Control
		assert_int(part.mouse_filter).override_failure_message(str(part.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	for decor: Control in [stage.belt, stage.monitor, stage.baskets, stage.cabinet]:
		assert_int(decor.mouse_filter).override_failure_message(str(decor.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
		for child: Node in decor.get_children():
			if child is Control and child != stage.row_strip:
				(
					assert_int((child as Control).mouse_filter)
					. override_failure_message(str(child.name))
					. is_equal(Control.MOUSE_FILTER_IGNORE)
				)
	var slot: PanelContainer = screen._slots[2]
	var slot_hit: Control = _topmost_at(screen, slot.get_global_rect().get_center())
	assert_bool(slot_hit == slot or slot.is_ancestor_of(slot_hit)).is_true()
	var card: Control = screen._hand_box.cards()[0]
	var card_hit: Control = _topmost_at(screen, card.get_global_rect().get_center())
	assert_bool(card_hit == card or card.is_ancestor_of(card_hit)).is_true()
	# The gap between slots 1 and 2, on the belt's top face.
	var gap: Vector2 = Vector2(
		slot.get_global_rect().position.x - RowStrip.SEPARATION / 2.0,
		slot.get_global_rect().get_center().y
	)
	assert_object(_topmost_at(screen, gap)).is_same(wall)
	var bezel: Rect2 = stage.monitor.get_global_rect()
	var on_bezel: Vector2 = bezel.position + Vector2(4, 4)
	assert_object(_topmost_at(screen, on_bezel)).is_same(wall)


## The register (RegisterCabinet) at its rect, the stage's rattle target: its column, printer and
## slot, keypad, drawer and pull at their stage rects, every part a plain colour that takes no
## click. set_total_down() is kept for CHECKOUT's held look.
func test_the_register_cabinet() -> void:
	var screen: ShiftScreen = await _screen()
	var cabinet: RegisterCabinet = screen._cabinet
	assert_object(screen._register).is_same(cabinet)
	assert_that(cabinet.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.REGISTER_RECT))
	var parts: Dictionary[String, Rect2] = {
		"Column": ShiftStage.COLUMN_RECT,
		"Printer": ShiftStage.PRINTER_RECT,
		"PrinterSlot": ShiftStage.PRINTER_SLOT_RECT,
		"Keypad": ShiftStage.KEYPAD_RECT,
		"Drawer": ShiftStage.DRAWER_RECT,
		"Pull": ShiftStage.DRAWER_PULL_RECT,
	}
	for part_name: String in parts:
		var part: Control = cabinet.get_node(part_name) as Control
		assert_that(part.get_global_rect()).is_equal(_on_stage(screen, parts[part_name]))
		assert_bool(cabinet.get_global_rect().encloses(part.get_global_rect())).is_true()
	assert_bool(cabinet.is_total_down()).is_false()
	cabinet.set_total_down(true)
	assert_bool(cabinet.is_total_down()).is_true()
	cabinet.set_total_down(false)
	assert_bool(cabinet.is_total_down()).is_false()


## The hand is tray items (#75), and while the shift is counted the hand and its baskets fade
## to COUNTING_HAND_ALPHA; they come back once the count-up ends.
func test_the_hand_is_items_that_dim_while_counting() -> void:
	var screen: ShiftScreen = await _screen()
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(screen.run.balance.hand_size)
	for view: Control in views:
		assert_object(view).is_instanceof(ItemView)
		assert_int((view as ItemView).form).is_equal(ItemView.Form.TRAY)
	var stage: ShiftStage = screen._stage
	assert_float(stage.baskets.modulate.a).is_equal(1.0)
	assert_float(stage.hand.modulate.a).is_equal(1.0)
	# Read on the first frame of the count-up.
	var counting_alphas: Array[float] = []
	var record: Callable = func() -> void:
		counting_alphas.assign([stage.baskets.modulate.a, stage.hand.modulate.a])
	get_tree().process_frame.connect(record, CONNECT_ONE_SHOT)
	await screen._on_checkout_pressed()
	assert_int(counting_alphas.size()).is_equal(2)
	for alpha: float in counting_alphas:
		assert_float(alpha).is_equal_approx(ShiftStage.COUNTING_HAND_ALPHA, 0.001)
	assert_float(stage.baskets.modulate.a).is_equal(1.0)
	assert_float(stage.hand.modulate.a).is_equal(1.0)


## `window`'s band `part`: spanning the window and taking no click. Returns its rect.
func _band(window: Control, part: String, bounds: Rect2) -> Rect2:
	var band: Control = window.get_node(part) as Control
	var shown: Rect2 = band.get_global_rect()
	assert_float(shown.position.x).is_less_equal(bounds.position.x)
	assert_float(shown.end.x).is_greater_equal(bounds.end.x)
	assert_int(band.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	return shown


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


## The control a click at `point` reaches, picked as the GUI does: the last drawn visible
## control under the point that doesn't ignore the mouse (children over their parent, later
## siblings over earlier ones), or null.
static func _topmost_at(node: Node, point: Vector2) -> Control:
	for index: int in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		var item: CanvasItem = child as CanvasItem
		if item != null and not item.visible:
			continue
		var found: Control = _topmost_at(child, point)
		if found != null:
			return found
	var control: Control = node as Control
	if (
		control != null
		and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and control.get_global_rect().has_point(point)
	):
		return control
	return null


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
