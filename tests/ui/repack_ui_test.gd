extends GdUnitTestSuite
## The repack on the real screen (#122, a badge pin: RunPins.repack, RepackFlow): with the pin
## worn, a hand item picked up marks the empty places of the other baskets, each mark exactly on
## its place's item cell, inside its basket and the stage; a click on a mark moves the item there
## (logged as repack, saved). Marks draw nothing (no highlighted zone). A drag can drop on any
## place of another basket: an item there swaps; a place in the item's own basket takes nothing.
## Without the pin, or for an item picked from the belt, nothing is marked. The real saves and logs
## are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const REPACK := "res://data/pins/repack.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_no_pin_no_marks() -> void:
	var screen: ShiftScreen = await _screen()
	await _belt_first(screen)
	_pick(screen, 3)
	await _frames(2)
	assert_object(screen._picked).is_not_null()
	assert_array(screen._repack.marks()).is_empty()
	assert_int(screen._repack._place_at(screen._picked, _centre(screen, 0))).is_equal(-1)


## Basket 0's empty place (its item on the belt) is marked for the item at place 3, on its cell;
## a click there moves the item, logged and saved, and the marks go.
func test_a_click_on_a_mark_moves_the_item() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	RunPins.wear(run, [load(REPACK)])
	var belt: CardInstance = await _belt_first(screen)
	var lone: CardInstance = run.hand_places()[3]
	_pick(screen, 3)
	await _frames(2)
	var marks: Array[RepackMark] = screen._repack.marks()
	assert_int(marks.size()).is_equal(1)
	var mark: RepackMark = marks[0]
	assert_int(mark.place).is_equal(0)
	assert_bool(mark.has_method("_draw")).is_false()
	var cell: Rect2 = Rect2(
		screen._hand_box.get_global_rect().position + screen._hand_box.place_position(0),
		ItemView.BASKET_SIZE
	)
	assert_vector(mark.get_global_rect().position).is_equal_approx(cell.position, Vector2.ONE)
	assert_vector(mark.get_global_rect().size).is_equal_approx(cell.size, Vector2.ONE)
	var basket: Rect2 = _on_stage(screen, screen._stage.baskets.basket_rect(0))
	assert_float(mark.get_global_rect().get_center().x).is_between(basket.position.x, basket.end.x)
	assert_bool(screen._stage.get_global_rect().encloses(mark.get_global_rect())).is_true()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	mark.gui_input.emit(press)
	await _frames(2)
	assert_object(run.hand_places()[0]).is_same(lone)
	assert_object(run.hand_places()[3]).is_null()
	assert_array(run.row).is_equal([belt])
	assert_object(screen._picked).is_null()
	assert_array(screen._repack.marks()).is_empty()
	var event: Dictionary = _last_event("repack")
	assert_int(int(event["from"])).is_equal(3)
	assert_int(int(event["to"])).is_equal(0)
	assert_bool(event["from_belt"]).is_true()
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_int(saved.run.hand()[0].instance_id).is_equal(lone.instance_id)


## A drop on another basket's item swaps the two; its own
## basket's place takes nothing.
func test_a_drag_swaps_with_another_baskets_item() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	RunPins.wear(run, [load(REPACK)])
	var picked: CardInstance = run.hand_places()[3]
	var other: CardInstance = run.hand_places()[5]
	_pick(screen, 3)
	await _frames(2)
	var flow: RepackFlow = screen._repack
	assert_int(flow._place_at(picked, _centre(screen, 2))).is_equal(-1)
	assert_int(flow._place_at(picked, _centre(screen, 5))).is_equal(5)
	screen._drag.place_dropped.emit(picked, 5)
	await _frames(2)
	assert_object(run.hand_places()[5]).is_same(picked)
	assert_object(run.hand_places()[3]).is_same(other)
	assert_int(run.redraws_used).is_equal(0)
	assert_bool(_last_event("repack")["from_belt"]).is_false()


## An item taken back from the belt is picked from the row: it marks nothing.
func test_a_belt_item_marks_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	RunPins.wear(screen.run, [load(REPACK)])
	await _belt_first(screen)
	var row_view: CardView = screen._row_views[0]
	screen._on_row_card_clicked(row_view)
	await _frames(2)
	assert_bool(screen._picked_from_row).is_true()
	assert_array(screen._repack.marks()).is_empty()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


## Places the item at place 0 on the belt, leaving basket 0's place 0 empty.
func _belt_first(screen: ShiftScreen) -> CardInstance:
	var card: CardInstance = screen.run.hand_places()[0]
	screen.run.place(card, 0)
	screen._refresh()
	await _frames(2)
	return card


static func _pick(screen: ShiftScreen, place: int) -> void:
	screen._on_hand_card_clicked(screen._hand_box.view_at(place) as CardView)


static func _centre(screen: ShiftScreen, place: int) -> Vector2:
	var corner: Vector2 = (
		screen._hand_box.get_global_rect().position + screen._hand_box.place_position(place)
	)
	return corner + ItemView.BASKET_SIZE / 2.0


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
