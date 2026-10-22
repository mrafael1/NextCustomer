extends GdUnitTestSuite
## The belt items' corner marks and paid chips on the real shift screen (#80, step 7, BeltChips),
## retired by #86 v6 (mock-up count_up_86_v6_scan): planning shows #71's stickers, never a mark or
## a paid chip, and follows every place and remove; the count shows none on any frame, with or
## without reduced motion (the stickers fire, the receipt and the monitor show the pay), though
## the denied item's beat still plays; and a resumed checkout's belt shows none (its items are in
## the bag). The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]

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


## Planning's effects follow the row on every place and remove, as stickers (#71), never as marks
## or paid chips: Coffee alone fizzles (no Breakfast product after it); Bread placed after it takes
## Coffee's +3 and Coffee's fizzle goes; Bread taken back out brings the fizzle back.
func test_planning_shows_stickers_never_marks_or_paid_chips() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee"])
	_assert_no_marks_or_chips(screen, "coffee")
	assert_array(_chip_texts(screen, 0)).contains(["pfff"])
	await _place(screen, ["bread"])
	_assert_no_marks_or_chips(screen, "bread")
	assert_array(_chip_texts(screen, 0)).not_contains(["pfff"])
	assert_array(_chip_texts(screen, 1)).contains(["+3"])
	# Bread taken out of the row and let go: back in the hand.
	screen._on_row_card_clicked(screen._row_views[1])
	screen._let_go()
	await _frames(2)
	assert_int(screen.run.row.size()).is_equal(1)
	_assert_no_marks_or_chips(screen, "out")
	assert_array(_chip_texts(screen, 0)).contains(["pfff"])


## The count shows no mark and no paid chip on any frame, with or without reduced motion, though
## the count-up shows each item's value (ItemView.show_badge, turned off by the belt ride) and the
## Spot check's denied beat plays.
func test_the_count_shows_no_mark_or_paid_chip() -> void:
	for reduced: bool in [false, true]:
		var screen: ShiftScreen = await _screen()
		screen._debug.set_reduced_motion(reduced)
		await _full_row(screen)
		var denied: Array[int] = [0]
		screen._count_up.beat_started.connect(
			func(beat: CountUpBeat, _s: ScoreStep, _l: String, _v: CardView, _i: int) -> void:
				if beat.kind == CountUpBeat.Kind.DENIED:
					denied[0] += 1
		)
		screen._on_checkout_pressed()
		var frames: int = 0
		while screen._counting:
			await get_tree().process_frame
			frames += 1
			_assert_no_marks_or_chips(screen, "frame %d" % frames)
		assert_int(frames).is_greater(10)
		assert_int(denied[0]).is_equal(1)
		_assert_no_marks_or_chips(screen, "after")


## A resumed checkout's belt (show_all after the checkout) shows no mark or paid chip: its items
## are in the bag, the belt empty.
func test_a_resumed_checkout_shows_no_mark_or_paid_chip() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	for view: CardView in screen._row_views:
		view.show_badge(3, false)
		(view as ItemView).show_mark(false)
	screen._show_checked_out(result)
	screen._ride.show_end_state(screen._row_views)
	await _frames(2)
	_assert_no_marks_or_chips(screen, "resumed")
	for cell: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
		assert_bool(cell.visible).is_false()
	assert_int(screen._stage.bag.items().size()).is_equal(FULL_ROW.size())


func _assert_no_marks_or_chips(screen: ShiftScreen, when: String) -> void:
	for slot: int in range(screen._row_views.size()):
		var item: ItemView = screen._row_views[slot] as ItemView
		if item == null:
			continue
		var at: String = "%s, slot %d" % [when, slot]
		assert_bool(item.badge.visible).override_failure_message(at).is_false()
		assert_object(item._mark).override_failure_message(at).is_null()


## The texts of the planning stickers on the belt item in `slot` (#71, mock-up h1).
static func _chip_texts(screen: ShiftScreen, slot: int) -> Array[String]:
	var texts: Array[String] = []
	for sticker: EffectSticker in screen._stage.planning_layer.stack(slot):
		texts.append(sticker.text())
	return texts


## A new run's screen: an earlier screen's run save in the test folder is removed first, so the
## screen never resumes it (since #77 a new run saves at once, with no impulse rack before it).
func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	var placed: int = screen.run.row.size()
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(placed + ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: Control in screen._hand_box.cards():
		if (view as CardView).card == card:
			return view as CardView
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
